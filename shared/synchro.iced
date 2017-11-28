setImmediate = if process.setImmediate?
  process.setImmediate
else
  (fn) -> setTimeout fn, 0

class SimpleLock
  constructor: ->
    @_running = false
    @_waiting = []

  acquire: (fn) ->
    @_waiting.push fn
    @_consider_run()

  release: ->
    @_running = false
    await setImmediate defer()
    @_consider_run()

  _consider_run: (fn) ->
    return if @_running or @_waiting.length is 0

    next = @_waiting[0]
    @_waiting.shift()
    @_running = true
    next()

class SimpleQueue
  constructor: (@_handler) ->
    @_q = []
    @_consuming = false
    @_destroyed = false

  destroy: ->
    @_destroyed = true

  push: (obj) ->
    if @_destroyed
      throw new Error "queue has been destroyed!"
    @_q.push obj
    @_maybe_consume()

  _maybe_consume: ->
    if (@_consuming or @_destroyed or @_q.length is 0)
      return

    @_consuming = true
    await @_handler @_q[0], defer err
    @_consuming = false
    # TODO: if err, maybe don't consume
    @_q = @_q.slice 1

    await setImmediate defer()
    @_maybe_consume()


exports.SimpleLock = SimpleLock
exports.SimpleQueue = SimpleQueue