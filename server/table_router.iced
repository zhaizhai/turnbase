{V} = require 'shared/T/validation.iced'

EventEmitter = (require 'events').EventEmitter
{TableServer} = require 'server/table_server.iced'
{AppRouter} = require 'server/server_util.iced'

{User} = require 'server/user.iced'
{PollProvider, LatestDataProvider} = require 'server/poll_server.iced'

{GAMES} = require 'server/server_config.iced'


class PresenceList
  ACTIVITY_TIMEOUT_MS = 60 * 1000

  constructor: (@user_store) ->
    @_active_users = {}
    @_dp = new LatestDataProvider (@_package.bind @)

    do_reap = =>
      @reap_users()
      setTimeout do_reap, ACTIVITY_TIMEOUT_MS
    do_reap()

  provider: -> @_dp

  reap_users: ->
    now = (new Date).valueOf()
    users_changed = false
    new_active = {}
    for uid, info of @_active_users
      if (now - info.last_active) > ACTIVITY_TIMEOUT_MS
        users_changed = true
      else
        new_active[uid] = info
    @_active_users = new_active
    if users_changed
      @_dp.update()

  ack_user: (uid, cb) ->
    if not @_active_users[uid]?
      await @user_store.get_user uid,
        defer err, user
      if err then return cb err
      if not uid? then return cb "err: unknown user"

      @_active_users[uid] = {
        last_active: (new Date).valueOf()
        user: user
      }
      @_dp.update()
      return cb null
    @_active_users[uid].last_active = (new Date).valueOf()
    return cb null

  _package: (cid, cb) ->
    # TODO: this should occur before packaging
    await @ack_user cid, defer err
    if err then return cb err

    ret = {}
    for uid, info of @_active_users
      ret[uid] = User.dump_json info.user
    return cb null, ret


# TODO: should this extend PollProvider?
class TableRouter extends EventEmitter
  constructor: (deps) ->
    {@poll_server, @chat_server, # TODO: validate
     @login_server, @user_store} = deps

    @_table_server_map = {}
    @_next_tid = 0

    @_pl = new PresenceList @user_store
    @poll_server.register_provider 'user-list', @_pl.provider()

    @poll_server.register_provider 'table-list', @
    @_cursor = 0

  # impl PollServer
  get_cursor: -> @_cursor

  # impl PollServer
  get_data: (cid, since_cursor, cb) ->
    if @_cursor is since_cursor
      return cb null, null, @_cursor
    return cb null, @list_tables(), @_cursor

  _update: ->
    @_cursor++
    # TODO: do incremental updates
    @emit 'cursor-changed'

  list_tables: ->
    ret = []
    for tid, table_server of @_table_server_map
      ret.push {
        table_type: table_server.table.get_type()
        party_mode: table_server.party_mode
        tid: tid
        users: table_server.users.slice()
      }
    return ret

  _make_table_server: (tid, table_type, opts) ->
    config = GAMES[table_type]
    if not config?
      throw new Error "TODO: handle unrecognized table type #{table_type}"
    return new TableServer tid, config, opts, @poll_server, @user_store

  add_new_table: (table_type, opts) ->
    tid = 't' + (@_next_tid++)
    console.log 'Initializing new table with tid', tid
    console.log 'Options:', opts

    # TODO: validate opts here, especially that
    # opts.initial_data.num_players is a reasonable number
    opts.initial_data ?= {}
    table_server = @_make_table_server tid, table_type, opts
    table_server.on 'players-changed', =>
      @_update()
    @_table_server_map[tid] = table_server

    @chat_server.create_room "#{tid}:chat"
    @_update()
    return tid

  delete_table: (tid) ->
    # TODO: remove poll providers
    table_server = @_table_server_map[tid]
    table_server.destroy()
    delete @_table_server_map[tid]
    @_update()

  get_table: (tid) ->
    return @_table_server_map[tid]

  get_app_router: ->
    ar = new AppRouter
    ar.get '/:tid', {
      session:
        uid: (V.Nullable V.String)
      query:
        player_id: V.Integer
      params:
        tid: V.String
    }, (req, res) =>
      {uid, tid, player_id} = req.args
      if not uid?
        return @login_server.login_first req, res

      table_server = @get_table tid
      if not table_server?
        return res.status(400).send("no such table")

      user_agent = req.headers['user-agent']
      device = 'web'
      if /iPhone/i.test user_agent
        device = 'ios'
      else if /Android/i.test user_agent
        device = 'android'
      return table_server.handle_root uid, player_id, device, res

    ar.post '/:tid/join', {
      params:
        tid: V.String
      body:
        player_id: V.Integer
      session:
        uid: V.String
    }, (req, res) =>
      {uid, tid, player_id} = req.args
      table_server = @get_table tid
      if not table_server?
        return res.status(400).send("no such table")
      return table_server.handle_join uid, player_id, res

    ar.post '/:tid/kick', {
      params:
        tid: V.String
      body:
        player_id: V.Integer
      session:
        uid: V.String
    }, (req, res) =>
      {uid, tid, player_id} = req.args
      table_server = @get_table tid
      if not table_server?
        return res.status(400).send("no such table")
      return table_server.handle_kick uid, player_id, res

    ar.post '/:tid/poll', {
      params:
        tid: V.String
      body:
        cursors: V.Object # TODO: validate
      session:
        uid: V.String
    }, (req, res) =>
      {tid, uid, player_id, cursors} = req.args
      table_server = @get_table tid
      if not table_server?
        return res.status(400).send("no such table")

      for _, info of cursors
        # TODO: validate this properly
        info.cid = parseInt info.cid
        if not (V.Integer info.cid).outcome
          return res.status(400).send "Invalid cid #{info.cid}"
        # TODO: this assumes that cid is player_id
        player_id = info.cid
        if not table_server.authorize uid, player_id
          return res.send "uid #{uid} does not match player_id #{player_id}"

      POLL_DELAY = 50 * 1000
      @poll_server.longpoll cursors, POLL_DELAY, (info_map) ->
        return res.send info_map

    ar.post '/:tid/chat', {
      params:
        tid: V.String
      body:
        mesg: V.HtmlEscapedString
      session:
        uid: V.String
    }, (req, res) =>
      {tid, mesg, uid} = req.args
      # TODO: maybe we should validate that user is at table?

      await @user_store.get_user uid,
        defer err, user
      if err or not user?
        return res.status(500).send("could not find user #{uid}, error: #{err}")

      room_name = "#{tid}:chat"
      @chat_server.send_chat room_name, user.username, mesg
      return res.send "ok"

    ar.post '/:tid/rematch', {
      # TODO: more validation and auth
      params:
        tid: V.String
      body:
        player_id: V.Integer
    }, (req, res) =>
      {tid, player_id} = req.args
      # TODO: wait for all players to confirm
      table_server = @get_table tid
      if not table_server?
        return res.status(400).send("no such table")
      table_server.rematch()
      return res.send "ok"

    ar.post '/:tid/action', {
      # TODO: more validation and auth
      params:
        tid: V.String
      body:
        action_name: V.String
        player_id: V.Integer
        args: (x) ->
          if not x instanceof Array
            return V.r false, "args must be an array!"
          return V.r true
    }, (req, res) =>
      {tid, action_name, player_id, args} = req.args
      table_server = @get_table tid
      if not table_server?
        return res.status(400).send("no such table")
      table_server.handle_action player_id, {
        action_name, args
      }, res

    ar.get '/:tid/get_snapshot', {
      params:
        tid: V.String
      query:
        player_id: V.Integer
    }, (req, res) =>
      {tid, player_id} = req.args
      table_server = @get_table tid
      if not table_server?
        return res.status(400).send("no such table")
      table_server.handle_get_snapshot player_id, res

    # TODO: who should be allowed to request bot?
    ar.get '/:tid/request_bot', {
      params:
        tid: V.String
      query:
        bot_player_id: V.Integer
    }, (req, res) =>
      {tid, bot_player_id} = req.args
      table_server = @get_table tid
      if not table_server?
        return res.status(400).send("no such table")
      table_server.handle_request_bot bot_player_id, res

    return ar


exports.TableRouter = TableRouter
