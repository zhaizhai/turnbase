require 'bots/bot_util.iced'
http = require 'http'
url = require 'url'
querystring = require 'querystring'
domain = require 'domain'

{BOT_USERS} = require 'bots/bot_users.iced'
{GameClient} = require 'game_engine/client/game_client.iced'
{OpStream} = require 'game_engine/client/op_stream.iced'
{GameSpec} = require 'game_engine/game_spec.iced'

{$ajax} = require 'client/lib/http_util.iced'
{LongPollClient} = require 'client/lib/poll_client.iced'
{TableInfo} = require 'client/table_info.iced'
util_m = require 'shared/util.iced'


class BotInstance
  constructor: (@game_spec, @bot_ai, @tid, @player_id) ->
    # bot_ai is a function that takes (gc, player_id) and returns mode
    # handlers
    @lpc = null

  run: (cb) ->
    # TODO: This code is pretty old and the domain module has been in
    # a limbo "pending deprecation" state for multiple years
    # (2014-2019). Look into whether we can get rid of it. The main
    # functionality we need is just a "catch-all" so that one bot's
    # error doesn't crash the whole process. Might work to use the
    # cluster module.
    d = domain.create()
    d.on 'error', (err) =>
      console.error "Bot instance stopping due to error:", err.stack
      @lpc?.stop()
      d.dispose()
      # should be able to garbage collect BotInstance at this point
    d.run =>
      @_do_run cb

  _do_run: (cb) ->
    @lpc = new LongPollClient "/table/#{@tid}/poll"
    op_stream = new OpStream @lpc
    table_info = new TableInfo @tid, @player_id, @lpc
    gc = new GameClient @game_spec, table_info, @player_id, op_stream

    mode_handlers = @bot_ai gc, @player_id
    await gc.init mode_handlers, defer err
    if err then return cb err

    table_info.on 'table-closed', =>
      console.log "Table #{@tid} closed. Stopping bot instance."
      @lpc.stop()
      # TODO: do we need to also stop the GameClient?
    @lpc.run()
    return cb null


class BotServer
  constructor: (@game_spec, @bot_ai, @username, @password) ->
    @uid = null

  init: (cb) ->
    await $ajax.post '/login', {@username, @password},
      defer err, res
    console.log 'login', err, res
    if err then return cb err
    if not res.success
      return cb new Error "Login failed!"
    @uid = res.uid
    return cb null

  join_game: (tid, player_id, cb) ->
    if not @uid? then return cb new Error "Not logged in!"
    await $ajax.post "/table/#{tid}/join",
      {@uid, player_id}, defer err, res
    console.log 'join', err, res
    if err then return cb err

    # TODO: hack to get table info
    cursors = {}
    cursors["#{tid}:info"] =
      cid: player_id
      cursor: -1
    await $ajax.post "/table/#{tid}/poll",
      {cursors}, defer err, res
    console.log 'initial table info', err, res
    if err then return cb err
    global.TEMPLATE_PARAMS =
      uid: @uid
      table_info: res["#{tid}:info"].data

    bot = new BotInstance @game_spec, @bot_ai, tid, player_id
    await bot.run defer err
    if err then return cb err
    return cb null

  run: (port = 3000) ->
    server = http.createServer (req, res) =>
      parsed_url = url.parse req.url
      {tid, player_id} = querystring.parse parsed_url.query
      # TODO: validation
      player_id = parseInt player_id

      await @join_game tid, player_id, defer err
      if err
        console.log 'join error', err
        res.writeHeader 400
        res.write err
        return res.end()

      res.writeHeader 200, {
        'Content-Type': 'application/json'
      }
      res.write '{success: true}'
      res.end()
    console.log 'Bot server on port', port
    server.listen port


exit_error = (mesg) ->
  console.log mesg
  process.exit()

if process.argv.length isnt 4
  exit_error "Usage: iced bot_server.iced [game name] [bot name]"
game_type = process.argv[2]
bot_type = process.argv[3]

dynamic_require = (path) ->
  try
    ret = require path
  catch e
    console.log e
    exit_error "Unable to load module: #{path}"
  return ret
bot_module = dynamic_require "bots/#{game_type}/#{bot_type}.iced"
#game_module = dynamic_require "games/#{game_type}/#{game_type}.iced"
game_spec = new GameSpec game_type

user_info = util_m.clone BOT_USERS[game_type][bot_type]
user_info.signup = true

# Create bot user. If it already exists, this should do nothing.
await $ajax.post "/login", user_info, defer err, res
if err
  console.log 'login error:', (err.mesg ? err)
  throw err
if res.success
  console.log 'Created new bot user:', user_info.username
console.log 'Logged in'

# TODO: make bot user configurable
bot_server = new BotServer game_spec, bot_module.AI,
  user_info.username, user_info.password
await bot_server.init defer err
throw err if err
bot_server.run user_info.port
