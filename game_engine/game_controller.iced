assert = require 'assert'
seed_random_m = require 'seed-random'
util_m = require 'shared/util.iced'
{GameState} = require 'game_engine/game_state.iced'
{V} = require 'shared/T/validation.iced'


class Operation
  constructor: (opts) ->
    DEFAULTS =
      exposed: false # whether the operation can be called within a block
#      final: false
    for k, v of DEFAULTS
      @[k] = opts[k] ? v

    {@name, @player_id, @perform, @log} = opts # TODO


# additional ops we might support later:
# DELIMIT
OPS =
  LEAVE_MODE:
    exposed: true
    perform: (gc, ret_val) ->
      @log.snapshot() # record action or continuation
      gc.leave_mode @player_id, ret_val

  ENTER_MODE:
    exposed: true
    perform: (gc, name, args, cont) ->
      @log.snapshot() # record action or continuation
      gc.enter_mode @player_id, name, args, cont
      @log.add({
        op: 'ENTER_MODE'
        mode_name: name
        args: util_m.clone args
      }).snapshot()

  LOG:
    exposed: true
    perform: (gc, mesg) ->
      last = @log.last()
      assert last?
      last.mesgs ?= []
      last.mesgs.push mesg

  EXTRA_INFO:
    exposed: true
    perform: (gc, info) ->
      last = @log.last()
      assert last?
      last.extra ?= {}
      for k, v of info
        last.extra[k] = v

  GAME_OVER:
    exposed: true
    perform: (gc, end_data) ->
      @log.add {
        op: 'GAME_OVER'
        # TODO
      }
      @log.snapshot()

  CONTINUATION:
    perform: (gc, arg, fn) ->
      log_entry =
        op: 'CONTINUATION'
        player_id: @player_id # TODO
      @log.add log_entry
      gc.execute_block @player_id, [arg], fn
      # TODO: slightly hacky way of snapshotting if needed
      if @log.last() is log_entry
        @log.snapshot()

class Randomizer
  constructor: (@_seed) ->
    @_gen = seed_random_m @_seed
    @rand = => @_gen()
  seed: -> @_seed
  shuffle: (array) ->
    util_m.shuffle array, @_gen
  rand_int: (n) ->
    return Math.floor(@_gen() * n)


class Log
  constructor: (@_game_state) ->
    @_entries = []

  length: -> @_entries.length
  entries_since: (len) -> @_entries.slice(len)
  last: ->
    len = @_entries.length
    return if len > 0 then @_entries[len - 1] else null

  add: (entry) ->
    @_entries.push entry
    return @

  snapshot: ->
    if @last()?
      @last().snapshot =
        mode_name: @_game_state.mode().name
        json: @_game_state.snapshot()


class GameController
  # @gs is a GameState
  constructor: (game_spec, initial_data, seed = null) ->
    if seed?
      console.log "Creating seeded game with seed #{seed}"
    else
      seed = Math.random() + ''
    @_rand = new Randomizer seed

    initial_state = game_spec.setup.init.call {
      RANDOM: @_rand
    }, initial_data
    base_fields = (k for k, v of game_spec.base when v.type?)
    @gs = new GameState base_fields, initial_state

    @_modes = game_spec.modes
    @log = new Log @gs

    # TODO: a bit hacky here?
    @gs.push_mode @_modes.Main, {}, -1, ->

  get_seed: -> @_rand.seed()

  # package log entry
  package_log_entry: (player_id, entry) ->
    ret = util_m.clone entry
    if ret.snapshot?
      {json, mode_name} = ret.snapshot
      mode = @_modes[mode_name]
      snapshot = mode.struct.load_json json
      ret.snapshot = mode.struct.dump_json snapshot, player_id
      ret.mode_name = mode_name
    return ret

  perform_op: (player_id, op_name, args...) ->
    opts =
      player_id: player_id
      name: op_name
      log: @log
    for k, v of OPS[op_name]
      opts[k] = v
    op = new Operation opts
    op.perform @, args...

  execute_block: (player_id, args, block) ->
    ctx = @gs.state()

    # properties that will be added to the context
    ctx_props = ['PLAYER', 'RANDOM']
#    old_props = {PLAYER: ctx.PLAYER, RANDOM: ctx.RANDOM}
    # TODO: assert these are absent
    # TODO: or maybe have to save old values to accommodate generators?
    ctx.PLAYER = player_id
    ctx.RANDOM = @_rand
    for k, v of OPS
      if not v.exposed then continue
      ctx_props.push k

      do (k) =>
        ctx[k] = (op_args...) =>
          @perform_op player_id, k, op_args...

    result = block.apply ctx, args

    for prop in ctx_props # TODO: set to old?
      delete ctx[prop]

    return result

  enter_mode: (player_id, name, args, cont) ->
    mode = @_modes[name]
    if not mode?
      throw new Error "Invalid mode #{name}!"
    @gs.push_mode mode, args, player_id, cont

    # TODO: should we have a player_id here? or null?
    @execute_block player_id, [], mode.init

  leave_mode: (player_id, ret_val) ->
    prev_info = @gs.pop_mode()
    # TODO: unfortunately, it seems like we have to log here, even
    # though I wanted to put all logging in the ops
    @log.add {
      op: 'LEAVE_MODE'
      mode_name: @gs.mode().name
    }
    {player_id, continuation} = prev_info
    @perform_op player_id, 'CONTINUATION',
      ret_val, continuation


  action: (player_id, action_name, args) ->
    make_result = (entries, reason) ->
      return {entries, reason}

    if action_name[0] is '_'
      return make_result null, "Action #{cmd} starting with _ is invalid"

    cur_mode = @gs.mode()
    action = cur_mode.actions[action_name]
    if not action?
      return make_result null, "Invalid action #{action_name}"

    {types, validate, execute} = action args...

    if types.length isnt args.length
      return V.r false, "Invalid number of arguments! (got #{args.length}, expected #{types.length})"
    for t, i in types
      # TODO: better validation?
      try
        args[i] = t.load_json args[i]
      catch e
        return V.r false, "Argument #{i} is invalid: #{e.message}"

    res = @execute_block player_id, [], validate
    if not res.outcome
      return make_result null, res.reason

    log_cursor = @log.length()
    log_entry = {
      op: 'ACTION'
      mode: cur_mode
      player_id: player_id
      action: action_name
      args: util_m.clone args
    }
    @log.add log_entry

    # XXX: Temporarily disable icedcoffeescript's trampolining. The
    # function f is used to trick icedcoffeescript into compiling its
    # runtime with this file.
    f = -> await setTimeout defer(), 0
    old_trampoline = iced.trampoline
    iced.trampoline = (fn) -> fn()
    @execute_block player_id, [], execute
    iced.trampoline = old_trampoline

    # TODO: slightly hacky way of snapshotting if needed
    if @log.last() is log_entry
      @log.snapshot()

    return make_result (@log.entries_since log_cursor)


exports.GameController = GameController