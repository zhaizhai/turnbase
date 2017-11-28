class StaleTracker
  constructor: ->
    @_last_marked = {}

  clear: (names...) ->
    for name in names
      delete @_last_marked[name]

  mark: (names...) ->
    now = (new Date).valueOf()
    for name in names
      @_last_marked[name] = now

  time_since_marked: (name) ->
    last_marked = @_last_marked[name]
    if not last_marked? then return null
    now = (new Date).valueOf()
    return (now - last_marked)


class Timer
  constructor: ->
    @start_time = null
    @_duration = null
    @_timeout_id = null

  _reset: ->
    @start_time = @_duration = @_timeout_id = null

  is_running: -> @_timeout_id?

  cancel: ->
    if @_timeout_id?
      clearTimeout @_timeout_id
      @_reset()

  start: (@_duration, on_done) ->
    @start_time = (new Date).valueOf()
    after_timeout = =>
      @_reset()
      on_done()
    @_timeout_id = setTimeout after_timeout, @_duration

  elapsed: ->
    if not @start_time? then return null
    now = (new Date).valueOf()
    # TODO: time is hopefully monotonic?
    return now - @start_time

  remaining: ->
    if not @start_time? then return null
    now = (new Date).valueOf()
    ret = @_duration - (now - @start_time)
    return Math.max ret, 0

  elapsed_ratio: ->
    if not @start_time? then return null
    now = (new Date).valueOf()
    # TODO: clamp?
    return (now - @start_time) / @_duration

exports.Timer = Timer
exports.StaleTracker = StaleTracker