log = (require 'shared/log.iced') 'test_game.iced'
assert = require 'assert'
synchro_m = require 'shared/synchro.iced'
{GameSpec} = require 'game_engine/game_spec.iced'
{GameClient} = require 'game_engine/client/game_client.iced'
{LinearDataProvider} = require 'server/poll_server.iced'


# An OpStream that simulates longpolling the server.
class DirectOpStream
  constructor: (@player_id, @gc, @provider) ->

  start: (info, op_handler, cb) ->
    snapshot =
      mode_name: @gc.gs.mode().name
      json: @gc.gs.snapshot @player_id
    game_over = false # TODO: handle game over

    cursor = @provider.get_cursor()
    q = new synchro_m.SimpleQueue op_handler

    @provider.on 'cursor-changed', =>
      # TODO: we rely on callbacks here being called synchronously,
      # otherwise clients won't immediately update
      @provider.get_data @player_id, cursor,
        (err, data, new_cursor) =>
          cursor = new_cursor
          for item in data
            q.push item

    return cb null, {game_over, snapshot}

  stop: -> # TODO


class GameTester
  mock_table_info = ->
    return {
      tid: 't0'
      on: ->
      game_id: -> 'g0'
      username_for_player: ->
    }

  constructor: (@spec, initial_data = {}) ->
    @_gc = @spec.make_instance initial_data
    num_players = initial_data.num_players ? @spec.default_num_players

    @_provider = new LinearDataProvider (cid, data) =>
      return @_gc.package_log_entry cid, data

    @_clients = []
    for i in [0...num_players]
      @_clients.push (@_create_client i)
    @_initialized = false

  init: (cb) ->
    assert (not @_initialized), "Already initialized!"
    # suppress warnings for using default mode handlers
    log.set_flag 'warn', false
    for client in @_clients
      await client.init {}, defer()
    log.set_flag 'warn', true
    return cb()

  is_valid: (player_id, action, args) ->
    # TODO: potentially surface reason for invalidity as well
    return @_clients[player_id].is_valid action, args

  test_actions: (action_list, cb) ->
    # All errors are thrown here; use @is_valid to test that invalid
    # actions are correctly detected.

    old_RPC = GameClient.RPC
    GameClient.RPC =
      action: (tid, action_data, cb) =>
        {player_id, action_name, args} = action_data
        res = @_gc.action player_id, action_name, args
        if not res.entries?
          throw new Error res.reason
        for entry in res.entries
          log.info 'ENTRY', entry
          @_provider.add_data entry
        return cb null, res
      rematch: (tid, player_id, cb) =>
        throw new Error "TODO: handle rematch" # TODO

    if (not @_initialized)
      await @init defer()

    for [player_id, action, args] in action_list
      await @_clients[player_id].submit_action action, args,
        defer err, res
      if err?
        GameClient.RPC = old_RPC
        throw err

    GameClient.RPC = old_RPC
    return cb()

  mode_name: -> @_gc.gs.mode().name
  server_state: -> @_gc.gs.state()

  dump_state: ->
    mode_struct = @_gc.gs.mode().struct
    return JSON.stringify(mode_struct.dump_json @_gc.gs.state())

  _create_client: (player_id) ->
    op_stream = new DirectOpStream player_id, @_gc, @_provider
    return new GameClient @spec, mock_table_info(),
      player_id, op_stream


exports.GameTester = GameTester
