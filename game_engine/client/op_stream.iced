assert = require 'assert'
{$ajax} = require 'client/lib/http_util.iced'
synchro_m = require 'shared/synchro.iced'


class OpStream
  constructor: (@lpc) ->
    @started = false
    @q = null

  # op_handler: (op, cb) ->
  start: (game_info, op_handler, cb) ->
    assert (not @started), "Op stream has already been started!"
    @started = true

    {game_id, tid, player_id} = game_info
    await $ajax.get "/table/#{tid}/get_snapshot", {
        player_id: player_id
      }, defer err, res
    if err
      throw new Error "TODO: handle get snapshot error"
    @_initial_cursor = res.poll_from
    {game_over, snapshot} = res

    @q = new synchro_m.SimpleQueue op_handler
    @lpc.register_handler "#{tid}:game:#{game_id}",
      player_id, res.poll_from, (data_list) =>
        for data in data_list
          @q.push data

    return cb null, {game_over, snapshot}

  stop: ->
    @started = false
    @q.destroy()

exports.OpStream = OpStream