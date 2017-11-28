


class Timer
  constructor: (@fps = 40) ->
    @_start = null
    @_on_refresh = null

    @_timeout_id = null

  start: (@_on_refresh = null) ->
    @_start = (new Date).valueOf()
    do_refresh = =>
      # goes before in case timer is stopped during _on_refresh
      @_timeout_id = setTimeout do_refresh, (1000 / @fps)
      @_on_refresh?()
    do_refresh()

  time: ->
    return (new Date).valueOf() - @_start

  stop: ->
    clearTimeout @_timeout_id if @_timeout_id?

# TODO: make segments
class Trajectory
  constructor: (opts) ->
    {@start, @end, @duration} = opts # TODO
    @time_change = opts.time_change ? null
    # TODO: assert @time_change maps 0 -> 0, 1 -> 1

  get_pos: (t) ->
    if @time_change?
      t = @time_change t

    ratio = t / @duration
    x = start.x + ratio * (end.x - start.x)
    y = start.y + ratio * (end.y - start.y)
    return {x: x, y: y}


class CardAnimation
  constructor: (@_trajectories) ->



