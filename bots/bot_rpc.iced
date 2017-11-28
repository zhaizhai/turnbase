http = require 'http'
querystring = require 'querystring'
{BOT_USERS} = require 'bots/bot_users.iced'

class BotServerRPC
  # TODO: specify bot type
  @request_bot = (game_name, tid, bot_player_id, cb) ->
    bot_info = null
    for k, v of BOT_USERS[game_name]
      bot_info = v
    if not bot_info?
      return cb (new Error "No bots available for #{game_name}")

    opts =
      hostname: 'localhost'
      port: bot_info.port
      method: 'GET'
      path: '/?' + querystring.stringify {
        tid: tid, player_id: bot_player_id
      }
    req = http.get opts, (res) ->
      res.setEncoding 'utf8'
      res_data = ''
      res.on 'data', (chunk) ->
        res_data += chunk
      res.on 'end', ->
        # TODO: consider res.statusCode?
        try
          ret_data = (JSON.parse res_data)
        catch err
          # TODO: maybe error here?
          return cb null, ret_data
        return cb null, ret_data
    req.on 'error', (err) ->
      console.log 'request bot error', err
      # TODO: handle aborted
      return cb err

    return # TODO: allow abort?

exports.BotServerRPC = BotServerRPC

