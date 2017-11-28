assert = require 'assert'
util_m = require 'shared/util.iced'

{T, struct} = require 'shared/T/T.iced'
{V} = require 'shared/T/validation.iced'


# TODO: make this server-side only; client only needs to see latest
# snapshots I think?
# TODO: rename probably
class GameState
  @load_snapshot = -> # TODO

  @dump_snapshot = (state, player_id = null) -> # TODO

  constructor: (@_base_fields, base) ->
    # @_base_fields is a list of all the fields in the base state
    @_mode_stack = []
    @_state = base
    @_cur_mode = null

  state: -> @_state

  mode: -> @_cur_mode

  update: (snapshot) ->
    @_state = @_cur_mode.struct.load_json snapshot

  snapshot: (player_id) ->
    return @_cur_mode.struct.dump_json @_state, player_id

  push_mode: (mode, args, player_id, continuation) ->
    @_mode_stack.push {
      mode: @_cur_mode
      old_state: @_state
      player_id: player_id
      continuation: continuation
    }

    args = util_m.clone args
    for attr in @_base_fields
      args[attr] = @_state[attr]
    @_state = new mode.struct args
    @_cur_mode = mode

  pop_mode: ->
    assert @_mode_stack.length > 0
    top = @_mode_stack.pop()
    for attr in @_base_fields
      # the shared state needs to be resynced
      top.old_state[attr] = @_state[attr]
    @_state = top.old_state
    @_cur_mode = top.mode
    return {
      player_id: top.player_id
      continuation: top.continuation
    }



exports.GameState = GameState