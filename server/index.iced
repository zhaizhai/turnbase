require 'server/init_games.iced'

user_m = require 'server/user.iced'
{UserStore, MemoryUserStore, User} = user_m
if process.env.GAMES_NO_MYSQL?
  UserStore = MemoryUserStore

{GameStore} = require 'server/game_store.iced'
{TestingStore} = require 'server/testing_server.iced'

server_m = require 'server/server.iced'
mysql = require 'mysql'

g_user_store = null
g_testing_store = null
g_game_store = null

init_stores = (cb) ->
  # TODO: real secret
  pool = mysql.createPool {
    host: '127.0.0.1'
    user: ''
    password: ''
    database: 'turnbase'
  }

  g_user_store = new UserStore pool
  await g_user_store.init defer err
  return cb err if err

  g_game_store = new GameStore pool
  await g_game_store.init defer err
  return cb err if err

  g_testing_store = new TestingStore pool, g_game_store
  await g_testing_store.init defer err
  return cb err if err

  return cb null

start = (port_num, cb) ->
  await init_stores defer err
  throw err if err

  master_server = server_m.setup_app {
    user_store: g_user_store
    testing_store: g_testing_store
    game_store: g_game_store
  }
  master_server.app.listen port_num
  console.log "Server is running (port #{port_num})"
  return cb null, master_server

await start 8888, defer err, ms
