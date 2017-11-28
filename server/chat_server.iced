util_m = require 'shared/util.iced'

poll_server_m = require 'server/poll_server.iced'
{PollProvider, LinearDataProvider} = poll_server_m


class ChatProvider extends PollProvider
  constructor: ->
    @_history = []
    # @_creation = (new Date).getTime()
    @_cursor = 0
    @_offset = 0

  get_cursor: -> @_cursor

  get_data: (cid, since_cursor, cb) ->
    since = Math.max 0, (since_cursor - @_offset)
    data_since = @_history.slice since
    return cb null, data_since, @_cursor

  add_chat: (username, mesg) ->
    # TODO: should we actually escape html here instead of earlier?
    @_history.push {
      username: username
      mesg: mesg
      timestamp: (new Date).getTime()
    }
    @_cursor++
    @emit 'cursor-changed'

  last_activity: ->
    last = util_m.last @_history
    if not last?
      return null
    return last.time

  clear_history_before: (timestamp) ->
    # TODO: can be more efficient if needed
    while (@_history.length > 0 and
           @_history[0].timestamp < timestamp)
      @_history.splice 0, 1
      @_offset++



class ChatServer
  # TODO: probably methods here should be async
  CHAT_STALE_THRESHOLD_MS = 60 * 60 * 1000
  CHECK_STALE_DELAY_MS = 60 * 1000

  constructor: (@poll_server) ->
    @_rooms = {}

    # TODO: we can probably do clearing on every poll
    do_clear = =>
      @clear_history()
      setTimeout do_clear, CHECK_STALE_DELAY_MS
    do_clear()

  clear_history: ->
    now = (new Date).valueOf()
    for name, room of @_rooms
      room.clear_history_before (now - CHAT_STALE_THRESHOLD_MS)

  create_room: (room_name) ->
    # TODO: garbage collect unused rooms
    cp = new ChatProvider()
    @poll_server.register_provider room_name, cp
    @_rooms[room_name] = cp

  send_chat: (room_name, username, mesg) ->
    # if not @_rooms[room_name]?
    #   @create_room room_name
    @_rooms[room_name].add_chat username, mesg


exports.ChatServer = ChatServer