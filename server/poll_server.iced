EventEmitter = (require 'events').EventEmitter
util_m = require 'shared/util.iced'


class PollProvider extends EventEmitter
  # event: cursor-changed
  constructor: ->
    throw new Error "abstract"

  # gets the current cursor
  get_cursor: ->
    throw new Error "abstract"

  # gets data since a cursor, null if no data
  # cb err, data?, next_cursor
  get_data: (cid, since_cursor, cb) ->
    throw new Error "abstract"


class LinearDataProvider extends PollProvider
  constructor: (@prehook) ->
    @_data_list = []
    @_cursor = 0

  add_data: (item) ->
    @_data_list.push (util_m.clone item)
    @_cursor++
    @emit 'cursor-changed'

  add_data_batch: (items) ->
    for item in items
      @_data_list.push (util_m.clone item)
      @_cursor++
    if items.length > 0
      @emit 'cursor-changed'

  get_cursor: -> @_cursor

  get_data: (cid, since_cursor, cb) ->
    data_since = @_data_list.slice since_cursor
    processed_data = []
    for d in data_since
      processed_data.push (@prehook cid, d)
    return cb null, processed_data, @_cursor


class LatestDataProvider extends PollProvider
  constructor: (@_package_fn) ->
    @_cursor = 0

  get_cursor: ->
    return @_cursor

  get_data: (cid, since_cursor, cb) ->
    if @_cursor is since_cursor
      return cb null, null, @_cursor

    @_package_fn cid, (err, packaged) =>
      return cb err if err
      return cb null, packaged, @_cursor

  update: ->
    @_cursor++
    @emit 'cursor-changed'


class PubChannel
  constructor: ->
    @_subs = {}
    @_next_subid = 0

  notify: (args...) ->
    to_run = []
    for subid, handler of @_subs
      to_run.push handler

    @_subs = {}
    for handler in to_run
      handler args...

  subscribe_once: (handler) ->
    subid = @_next_subid++
    @_subs[subid] = handler
    return subid

  unsubscribe: (subid) ->
    delete @_subs[subid]


class PollServer
  # TODO: the utility of these prov_ids versus just using more channels
  # is questionable
  PROV_ID_CHARS = '0123456789' +
    'abcdefghijklmnopqrstuvwxyz'
  make_prov_id = ->
    ret = 'pr_'
    for i in [0...12]
      ret += (util_m.rand_choice PROV_ID_CHARS)
    return ret

  constructor: ->
    @_channel_info = {}

  register_provider: (channel, provider) ->
    if channel of @_channel_info
      throw new Error "channel #{channel} already has a provider!"
    prov_id = make_prov_id()
    @_channel_info[channel] =
      provider: provider
      pub: new PubChannel
      prov_id: prov_id
    provider.on 'cursor-changed', =>
      # TODO: we'd like to collapse multiple synchronous notifies into
      # a single one
      @_channel_info[channel].pub.notify()
    console.log "registered provider for channel #{channel} (prov_id: #{prov_id})"

  remove_provider: (channel) ->
    removed = @_channel_info[channel]
    delete @_channel_info[channel]
    removed.pub.notify {
      new_prov_id: null
    }
    console.log 'removed provider for channel', channel

  # channel_req_map[channel] = {
  #   prov_id, cid, cursor
  # }
  #
  # handler is called with (data_map), where
  # data_map[channel] = {
  #   error, data, next_cursor, prov_id
  # }
  longpoll: (channel_req_map, timeout_ms, handler) ->
    # TODO(joy): temporarily disable this logging while testing 1v1. undo
    # console.log "received longpoll on", channel_req_map

    channel_info = {} # make copy in case channels change
    # TODO: we serve stale prov_ids... is that bad?
    for channel of channel_req_map
      unless channel of @_channel_info
        ret = {}
        # TODO: come up with a convention for this kind of error
        ret[channel] = {error: 'ERR_INVALID_CHANNEL'}
        return handler ret
      channel_info[channel] = @_channel_info[channel]

    get_data = (channel, cb) ->
      req = channel_req_map[channel]
      container =
        prov_id: channel_info[channel].prov_id
      if req.prov_id? and req.prov_id isnt container.prov_id
        return cb container

      await channel_info[channel].provider.get_data req.cid, req.cursor,
        defer err, data, next_cursor
      if err
        container.error = err
      else
        container.data = data
        container.next_cursor = next_cursor
      return cb container

    gather_data = (channels, cb) =>
      channel_data_map = {}

      ct = channels.length
      for channel in channels
        do (channel) =>
          await get_data channel, defer container
          channel_data_map[channel] = container
          ct -= 1
          if ct == 0
            return cb channel_data_map

    return_immediately = false
    ret_channels = []
    for channel, req of channel_req_map
      {provider, pub} = channel_info[channel]
      if req.cursor isnt provider.get_cursor()
        ret_channels.push channel
        return_immediately = true
    if return_immediately
      return gather_data ret_channels, handler

    subids = {}
    timeout_id = null

    on_timeout = =>
      # TODO: we don't return prov_ids here even if the client doesn't
      # know them yet. I didn't implement this because we need to
      # rethink prov_ids altogether.
      for channel, subid of subids
        channel_info[channel].pub.unsubscribe subid
      return handler {}
    timeout_id = setTimeout on_timeout, timeout_ms

    for channel, cursor of channel_req_map
      {provider, pub} = channel_info[channel]
      do (channel, cursor, provider, pub) =>
        subids[channel] = pub.subscribe_once (status_info) =>
          clearTimeout timeout_id
          for c, subid of subids
            continue if c == channel
            channel_info[c].pub.unsubscribe subid

          if status_info?
            ret = {}
            ret[channel] =
              prov_id: status_info.new_prov_id
            return handler ret
          return gather_data [channel], handler


exports.PollServer = PollServer
exports.PollProvider = PollProvider
exports.LinearDataProvider = LinearDataProvider
exports.LatestDataProvider = LatestDataProvider
