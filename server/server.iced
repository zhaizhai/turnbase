assert = require 'assert'
http = require 'http'
path = require 'path'
url = require 'url'

express = require 'express'
middleware = {}
middleware.cookieParser = require('cookie-parser')
middleware.bodyParser = require('body-parser')
middleware.session = require('express-session')
middleware.static = require('serve-static')

{T} = require 'shared/T/T.iced'
{V} = require 'shared/T/validation.iced'
templates_m = require 'server/templates.iced'
{TestingServer} = require 'server/testing_server.iced'
{TableRouter} = require 'server/table_router.iced'
{TableReaper} = require 'server/table_reaper.iced'

{GAMES, LOGIN_SECRET} = require 'server/server_config.iced'
{GameTable} = require 'server/game_table.iced'

poll_server_m = require 'server/poll_server.iced'
{PollServer, LatestDataProvider} = poll_server_m

{ChatServer} = require 'server/chat_server.iced'

user_m = require 'server/user.iced'
{User, UserStore} = user_m
{LoginServer} = require 'server/login_server.iced'

g_poll_server = new PollServer
g_table_router = null


class MasterServer
  constructor: (@app, @table_router) ->

exports.setup_app = (args) ->
  {user_store, testing_store, game_store} = args
  g_login_server = new LoginServer user_store
  g_chat_server = new ChatServer g_poll_server
  g_chat_server.create_room 'global:chat'

  g_deps =
    poll_server: g_poll_server
    login_server: g_login_server
    chat_server: g_chat_server
    user_store: user_store
  g_table_router = new TableRouter g_deps
  g_testing_server = new TestingServer g_table_router, user_store, testing_store

  mins_between_reaps = 1
  table_reaper = new TableReaper g_table_router,
    mins_between_reaps
  table_reaper.run()

  app = express()
  app.use(middleware.cookieParser LOGIN_SECRET)
  app.use(middleware.session {
    secret: LOGIN_SECRET, resave: false
    # TODO: figure out if we need resave:true here (see https://www.npmjs.com/package/express-session)
    saveUninitialized: false
  })
  # TODO: specify this for only a subset of routes by having a first
  # argument to app.use
  app.use (req, res, next) ->
    if req.signedCookies.uid? and not req.session.uid?
      req.session.uid = req.signedCookies.uid
    return next()

  # serve static files
  app.use(middleware.static(path.join(__dirname, '..', 'static')))
  app.use('/games', middleware.static(path.join(__dirname, '..', 'games')))
  app.use(middleware.bodyParser.json())

  # connect to root
  g_login_server.get_app_router().connect app, ''

  app.get '/', (request, response) ->
    console.log("=====================")
    render_template = templates_m.render_template
    uid = request.session.uid
    if not uid?
      return g_login_server.login_first request, response

    await user_store.get_user uid, defer err, user
    if not user? or err
      delete request.session.uid
      response.clearCookie 'uid'
      mesg = if err then err else "Session was invalid, please try again"
      return response.send mesg

    tmpl_params =
      js_deps: ['&jquery', 'nav_bar.iced', 'main']
      js_params: JSON.stringify {
        uid: uid
        username: user.username
      }

    await render_template 'main.mustache', tmpl_params,
      defer err, rendered_tmpl
    # TODO: more graceful error handling
    if err then return (response.send err)
    return (response.send rendered_tmpl)

  app.post '/table_list/create_table', (request, response) ->
    validation_result = V.validate_request request, {
      body:
        table_type: V.String
        party_mode: V.Boolean
        initial_data: V.Object # TODO: validate further
    }
    if validation_result?
      return response.status(400).send(validation_result)
    console.log "create_table:", request.body

    # TODO: validate
    initial_data = request.body.initial_data
    table_type = request.body.table_type

    created_tid = g_table_router.add_new_table table_type, {
      initial_data: initial_data
      party_mode: request.body.party_mode
    }
    response.send({tid: created_tid});

  app.post '/table_list/poll', (request, response) ->
    validation_result = V.validate_request request, {
      body:
        cursors: V.Object # TODO: validate these
    }
    if validation_result?
      return response.status(400).send(validation_result)

    {cursors} = request.body
    POLL_DELAY = 45 * 1000
    g_poll_server.longpoll cursors, POLL_DELAY, (poll_info) ->
      response.send poll_info

  # the global chat
  app.post '/chat', (request, response) ->
    validation_result = V.validate_request request, {
      body:
        mesg: V.HtmlEscapedString
      session:
        uid: V.String
    }
    if validation_result?
      return response.status(400).send(validation_result)

    {uid, mesg} = request.args
    await user_store.get_user uid,
      defer err, user
    if err or not user?
      return response.status(500).send("could not find user #{uid}, error: #{err}")

    g_chat_server.send_chat 'global:chat',
      user.username, mesg
    return response.send 'ok'

  g_table_router.get_app_router().connect app, '/table'
  g_testing_server.get_app_router().connect app, '/testing'

  # # catch-all
  # app.use (error, req, res, next) ->
  #   if error
  #     console.log "Error from #{req.url}:"
  #     console.log error
  #   return res.status(400).send(JSON.stringify error)
  return new MasterServer app, g_table_router
