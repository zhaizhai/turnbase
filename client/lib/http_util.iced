assert = require 'assert'

exports.$ajax = $ajax = (endpoint, data, req_type, cb) ->
  assert req_type is 'get' or req_type is 'post'

  if req_type is 'post'
    data = JSON.stringify data

  on_success = (res, status, xhr) ->
    # TODO: if server gives 500 will this be called?
    err = if xhr.status is 200 then null else xhr.status
    return cb err, res

  # status is one of 'timeout', 'error', 'abort', 'parsererror'
  on_error = (xhr, status, mesg) ->
    code = xhr.status
    return cb {code, status, mesg}

  return $.ajax {
    url: endpoint
    type: req_type
    contentType: "application/json"
    data: data
    success: on_success
    error: on_error
  }

$ajax.get = (endpoint, data, cb) ->
  return $ajax endpoint, data, 'get', cb

$ajax.post = (endpoint, data, cb) ->
  return $ajax endpoint, data, 'post', cb


class Backoff
  DEFAULT_SEQ = [100, 300]
  delay = 1000
  while delay < 5 * 60 * 1000
    DEFAULT_SEQ.push delay
    delay *= 1.5

  constructor: (@seq = null) ->
    @seq ?= DEFAULT_SEQ
    @idx = 0

  reset: ->
    @idx = 0

  next_wait: ->
    if @idx >= @seq.length
      return null
    ret = @seq[@idx]
    @idx++
    return ret


class Retry
  # TODO: provide mechanism for retrying earlier if requested
  constructor: (@is_recoverable, @backoff = null) ->
    @backoff ?= new Backoff
    @_running = false

    @_aborting = false
    @_timeout_id = null

  _do_try: (fn, cb) ->
    await fn defer err, args...
    if @_aborting
      @_aborting = false
      return
    if not err then return cb null, args...

    if (not @is_recoverable err) then return cb err
    nw = @backoff.next_wait()
    if not nw?
      console.log "Persistent error after many retries, giving up!"
      return cb err

    console.log "Error", err, "retrying after #{nw} ms"
    try_again = =>
      @_do_try fn, cb
      @_timeout_id = null
    @_timeout_id = setTimeout try_again, nw

  abort: ->
    if not @_running then return
    if @_timeout_id?
      clearTimeout @_timeout_id
      @_timeout_id = null
    else
      @_aborting = true
    @_running = false

  run: (fn, cb) ->
    if @_running
      throw new Error "Already running!"
    @_running = true
    @backoff.reset()
    await @_do_try fn, defer err, args...
    @_running = false
    return cb err, args...

exports.Backoff = Backoff
exports.Retry = Retry