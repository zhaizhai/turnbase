log = require('shared/log.iced') 'game_client.iced'
{EventEmitter} = require 'events'
assert = require 'assert'
util_m = require 'shared/util.iced'

{T} = require 'shared/T/T.iced'
{V} = require 'shared/T/validation.iced'
{$ajax} = require 'client/lib/http_util.iced'


class GameStateClient
  constructor: (@game_spec, @tid, @player_id) ->
    @_game_over = false
    @_mode = null
    @_state = null

  state: -> @_state
  mode: -> @_mode

  init: (mode_name, json) ->
    log.info 'Initializing GameStateClient in mode', mode_name
    @_game_over = false
    @_mode = @game_spec.modes[mode_name]
    @_state = @_mode.struct.load_json json

  process_op: (op_data) ->
    log.info 'Client processing op:', @player_id, op_data
    {op, snapshot} = op_data
    if op in ['ENTER_MODE', 'LEAVE_MODE']
      @_mode = @game_spec.modes[op_data.mode_name]

    # 'CONTINUATION', 'ACTION'
    if snapshot?
      @_state = @_mode.struct.load_json snapshot

    if op is 'GAME_OVER'
      @_game_over = true
      # TODO: anything else to do?

  mode_name: ->
    if @_game_over then return 'GameOver'
    return @_mode.name

  game_over: -> @_game_over


class GameClient extends EventEmitter
  @RPC = # can be overwritten for testing purposes
    action: (tid, action_data, cb) ->
      await $ajax.post "/table/#{tid}/action", action_data,
        defer err, res
      return cb err, res
    rematch: (tid, player_id, cb) ->
      await $ajax.post "/table/#{tid}/rematch", {player_id: player_id},
        defer err, res
      return cb err, res

  # tries to determine if an action handler is async
  is_async = (fn) ->
    if fn.length <= 1 then return false
    if fn.length is 2
      return true # TODO: maybe also check the second arg is called 'cb'
    throw new Error "Handler takes too many arguments:\n #{fn.toString()}"

  constructor: (@game_spec, @table_info, @player_id, @op_stream) ->
    T.Integer @player_id
    @tid = @table_info.tid
    @game_id = @table_info.game_id()
    assert @game_id?, "Missing game id!"

    log.info 'spec is', @game_spec
    @gsc = new GameStateClient @game_spec, @tid, @player_id

    @_mode_handlers = {}
    @_cur_handler = null

    @table_info.on 'new-game', (@game_id) =>
    @table_info.on 'users-changed', =>
      @emit 'users-changed'

  init: (mode_handlers, cb) ->
    await @op_stream.start {
      @game_id, @tid, @player_id
    }, (@_process_op.bind @), defer err,
      {game_over, snapshot}
    return cb err if err
    log.info 'initial snapshot', snapshot

    @gsc.init snapshot.mode_name, snapshot.json
    @_set_mode_handlers mode_handlers
    @_transition @gsc.mode().name
    log.info 'running GameClient with handlers', @_mode_handlers
    return cb null

  state: -> @gsc.state()
  mode_name: -> @gsc.mode().name
  is_running: -> @op_stream.started
  num_players: -> @table_info.num_players()
  username_for_player: (player_id, opts = {}) ->
    disambiguate = opts.disambiguate ? true
    placeholder = opts.placeholder ? true
    name = @table_info.username_for_player player_id, disambiguate
    if placeholder
      name ?= "[Player #{player_id + 1}]"
    return name

  is_valid: (action_name, args) ->
    cur_mode = @gsc.mode()
    if not cur_mode? then return false

    action = cur_mode.actions[action_name]
    if typeof action isnt 'function'
      throw new Error "#{cmd} is not a valid action!"
    {validate} = action.apply null, args

    state = @gsc.state()
    tmp = state.PLAYER
    state.PLAYER = @player_id
    result = (V.catch_asserts validate).apply state, []
    state.PLAYER = tmp
    # TODO: also report reason
    return result.outcome

  rematch: (cb) ->
    await GameClient.RPC.rematch @tid, @player_id,
      defer err, res
    return cb err if err
    return cb null, res

  submit_action: (action_name, args, cb) ->
    # TODO: make nicer default behavior in case of error (maybe show in chat)
    cb ?= (err, res) =>
      if err? then return alert err
      # TODO: better error response format
      if res isnt 'ok' then alert res
    action_data =
      action_name: action_name
      player_id: @player_id
      args: util_m.clone args
    await GameClient.RPC.action @tid, action_data,
      defer err, res
    return cb err if err
    return cb null, res

  _set_mode_handlers: (handler_map) ->
    mode_names = (k for k of @game_spec.modes)
    mode_names.push 'GameOver'
    for k in mode_names
      handler = handler_map[k]
      if not handler?
        log.warn "Using default handler for unhandled mode #{k}"
      handler ?=
        init: ->
        action: ->
        cleanup: ->

      if handler.update?
        bound_update = handler.update.bind handler
        handler.init ?= bound_update
        handler.action ?= bound_update

      @_mode_handlers[k] = handler

  _process_op: (op, cb) ->
    @gsc.process_op op
    op.username = @username_for_player op.player_id

    if op.mesgs?
      for mesg in op.mesgs
        @emit 'log-mesg', (@table_info.compile_log_mesg mesg)

    if op.op is 'ACTION'
      # no mode change
      if not @_cur_handler?
        return cb null
      h = @_cur_handler
      if is_async h.action
        await h.action op, defer()
      else
        h.action op

    else if op.op in ['ENTER_MODE', 'LEAVE_MODE', 'CONTINUATION', 'GAME_OVER']
      if op.op isnt 'LEAVE_MODE'
      	# TODO: temporary hack that relies on the fact that LEAVE_MODE
	# is immediately followed by CONTINUATION
        @_transition @gsc.mode_name()
      if op.op is 'GAME_OVER'
        @_game_over_cleanup()

    else
      throw new Error "Unrecognized message type #{op.op}"
    return cb null

  _transition: (new_mode_name) ->
    if @_cur_handler?
     @_cur_handler.cleanup.apply @_cur_handler, []
    @_cur_handler = @_mode_handlers[new_mode_name]
    @_cur_handler.init.apply @_cur_handler, []

  _game_over_cleanup: ->
    log.info 'Game is over: running GameClient cleanup'
    @op_stream.stop()
    # TODO: maybe remove for all events
    @removeAllListeners 'users-changed'

exports.GameClient = GameClient
