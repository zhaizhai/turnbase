{$ajax, Retry} = require 'client/lib/http_util.iced'

class LongPollClient
  constructor: (@endpoint) ->
    @req_info = {}
    @_retry = new Retry (err) ->
      # indicates probable connectivity loss
      return (err? and err.code is 0)
    @_pending_xhr = null
    @_running = false

  register_handler: (channel, cid, cursor,
                     handler, on_end = null) ->
    if channel of @req_info
      throw new Error "Channel #{channel} already has handler!"
    if not handler?
      throw new Error "missing handler!"

    # TODO: allow registering multiple handlers?
    @req_info[channel] =
      cid: cid
      cursor: cursor
      prov_id: null
      handler: handler
      on_end: on_end

    # re-send the latest request
    if @_running
      @stop()
      @run()

  clear_handler: (channel) ->
    delete @req_info[channel]

  await_changes: (cb) ->
    if @_pending_xhr?
      throw new Error "there is already a pending xhr!"
    data =
      cursors: {}

    for channel, info of @req_info
      data.cursors[channel] =
        cid: info.cid
        cursor: info.cursor
        prov_id: info.prov_id

    do_ajax = (cb) =>
      @_pending_xhr = $ajax.post @endpoint, data, cb
    await @_retry.run do_ajax, defer err, res
    @_pending_xhr = null
    return cb err, res

  stop: ->
    # TODO: what if we only want to reset state of a specific channel?
    if @_pending_xhr?
      @_retry.abort()
      @_pending_xhr.abort()
      @_pending_xhr = null
    @_running = false

  run: ->
    do_one_poll = =>
      await @await_changes defer err, res
      # TODO: provide mechanism for recovering if e.g. the connection
      # was lost

      if err
        console.log err, res
        throw new Error """
          longpoll error for #{@endpoint} not handled yet: #{err} \n (full response): #{JSON.stringify res}
        """

      for channel, res_info of res
        if res_info.error?
          throw new Error "TODO: don't know how to handle poll error yet: #{res_info.error}"

        req_info = @req_info[channel]
        # handler may have been removed
        if not req_info? then continue

        if (req_info.prov_id? and
            req_info.prov_id isnt res_info.prov_id)
          console.log "provider #{req_info.prov_id} ended on channel #{channel}"
          delete @req_info[channel]
          if req_info.on_end?
            # TODO: should we setImmediate here?
            req_info.on_end()
          continue

        if not res_info.next_cursor?
          throw new Error "got invalid next_cursor! info: #{JSON.stringify res_info}"
        req_info.cursor = res_info.next_cursor
        req_info.prov_id = res_info.prov_id
        req_info.handler res_info.data

      do_one_poll()

    @_running = true
    do_one_poll()

exports.LongPollClient = LongPollClient