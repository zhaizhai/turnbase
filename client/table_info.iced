{EventEmitter} = require 'events'

class TableInfo extends EventEmitter
  constructor: (@tid, @player_id, @lpc) ->
    @_users = TEMPLATE_PARAMS.table_info.users.slice()
    @_game_id = TEMPLATE_PARAMS.table_info.game_id
    @lpc.register_handler "#{@tid}:info",
      @player_id, -1, (@_update.bind @),
      (@_table_closed. bind @)

  _table_closed: ->
    @emit 'table-closed'

  _update: (data) ->
    # uid = data.owner
    if data.game_id isnt @_game_id
      @_game_id = data.game_id
      @emit 'new-game', @_game_id

    @_users = data.users
    # TODO: only emit when actually changed
    @emit 'users-changed'

  game_id: -> @_game_id
  num_players: -> @_users.length
  get_user: (player_id) -> @_users[player_id]

  username_for_player: (player_id, disambiguate = true) ->
    if not @_users[player_id]? then return null
    ret = @_users[player_id].username
    if not disambiguate then return ret

    for user_info, idx in @_users
      if (user_info?.username is ret and
          idx isnt player_id)
        ret += " (#{player_id + 1})"
        break
    return ret

  compile_log_mesg: (mesg) ->
    replacer = (match, player_id) =>
      parsed = parseInt player_id
      if not parsed? or (isNaN parsed)
        throw new Error "Unexpected macro #{player_id}"
      # TODO: also check player id in range?
      return (@username_for_player parsed) ? '[empty]'
    try
      return mesg.replace /\%\{(\w*)\}/g, replacer
    catch e
      return "[Invalid log message]: #{mesg}"


exports.TableInfo = TableInfo