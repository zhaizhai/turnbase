{V} = require 'shared/T/validation.iced'
util_m = require 'shared/util.iced'

templates_m = require 'server/templates.iced'
{GameStore} = require 'server/game_store.iced'
{AppRouter} = require 'server/server_util.iced'

class TestingStore
  constructor: (@_pool, @game_store) ->

  init: (cb) ->
    COLUMNS = [
      # TODO: potential trouble with overflowing JS "int"s
      ['id', 'INT(12) UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY']
      ['type', 'VARCHAR(64) NOT NULL']
      ['description', 'TEXT']
      ['game_id', 'INT(12) UNSIGNED NOT NULL']
      ['FOREIGN KEY (game_id)', 'REFERENCES games(id) ON DELETE CASCADE']
    ]

    col_str = ''
    for [name, type], idx in COLUMNS
      if idx > 0
        col_str += ', '
      col_str += "#{name} #{type}"

    query_str = "CREATE TABLE IF NOT EXISTS tests (#{col_str})"
    await @_query query_str, defer err, result
    return cb err if err
    return cb null

  _query: (q, data, cb) ->
    await @_pool.getConnection defer err, conn
    return cb err if err
    await conn.query q, data, defer err, result
    conn.release()
    return cb err if err
    return cb null, result

  get_tests: (type, cb) ->
    args = [type]
    await @_query 'SELECT * FROM tests WHERE tests.type=?', args,
      defer err, rows
    return cb err if err
    ret = for {description, game_id} in rows
      {
        description: description
        game_id: ('g' + game_id)
      }
    return cb null, ret

  delete_test: (game_id, cb) ->
    game_id_int = parseInt (game_id.slice 1)
    args = [game_id_int]
    await @_query 'DELETE FROM tests WHERE game_id=?', args,
      defer err, result
    return cb err if err
    return cb null

  save_test: (type, game_json, description, cb) ->
    # TODO: ideally this could be done in a transaction, but we'll be
    # a bit sloppy in testing code
    await @game_store.save type, game_json,
      defer err, game_id
    return cb err if err
    game_id_int = parseInt (game_id.slice 1)

    await @_query 'INSERT INTO tests SET ?', {
      type: type
      description: description
      game_id: game_id_int
    }, defer err, result
    if err
      console.log 'err', err
    return cb err if err
    return cb null


class TestingServer
  constructor: (@table_router, @user_store, @testing_store) ->

  get_app_router: ->
    ar = new AppRouter
    ar.get '/:game_type/list', {
      session:
        uid: V.String
      params:
        game_type: V.String
    }, (req, res) =>
      return @select_test req, res

    ar.get '/:game_type', {
      session:
        uid: V.String
      params:
        game_type: V.String
      query:
        game_id: (V.Nullable V.String)
    }, (req, res) =>
      return @do_test req, res

    ar.post '/save', {
      body:
        tid: V.String
        description: V.String
    }, (req, res) =>
      return @save_test req, res

    ar.post '/delete', {
      body:
        game_id: V.String
    }, (req, res) =>
      return @delete_test req, res

    return ar

  delete_test: (req, res) ->
    game_id = req.body.game_id
    # TODO: validate
    await @testing_store.delete_test game_id, defer err
    if err
      return res.status(500).send err
    return res.status(200).send 'ok'

  select_test: (req, res) ->
    game_type = req.params.game_type
    await @testing_store.get_tests game_type,
      defer err, games
    if err
      return res.status(500).send err

    choices = []
    for data in games
      choices.push {
        desc: data.description
        game_id: data.game_id
      }

    js_params = {choices, game_type}
    await templates_m.render_template 'templates/select_testing.mustache', {
        js_params: (JSON.stringify js_params)
        game_type: game_type
        js_deps: [
          '&jquery',
          '../testing/select_testing.iced'
        ]
      },
      defer err, rendered_tmpl
    if err
      return (res.send err)
    return (res.send rendered_tmpl)

  save_test: (req, res) ->
    tid = req.body.tid
    desc = req.body.description
    # TODO: validate

    # TODO: the naming here is confusing... maybe we should rename
    # TableRouter methods to get_server, etc.
    table_server = @table_router.get_table tid
    table = table_server.table
    game_type = table.get_type()
    game_json =
      seed: table.game_controller.get_seed()
      actions: table.get_action_log()

    await @testing_store.save_test game_type,
      game_json, desc, defer err
    if err
      return res.status(500).send err
    return res.status(200).send 'ok'

  do_test: (req, res) ->
    uid = req.session.uid
    await @user_store.get_user uid, defer err, user
    if err
      return res.status(500).send "Problem getting user #{uid}"

    table_type = req.params.game_type
    game_id = req.query.game_id
    opts =
      initial_data: {}

    if game_id?
      # TODO: temporary hack of grabbing game_store
      await @testing_store.game_store.load game_id,
        defer err, game_info
      if err
        return res.send "Error retrieving game (#{err})"
      {game_type, game_json} = game_info
      opts.seed = game_json.seed

    tid = @table_router.add_new_table table_type, opts
    table_server = @table_router.get_table tid
    # TODO: this is a bit hacky to reach in and grab num_players
    num_players = table_server.table.num_players

    for i in [0...num_players]
      table_server._register_player user, i

    if game_id?
      for action in game_json.actions
        table_server.table.perform_action action

    js_params = JSON.stringify {
      tid: tid
      uid: uid
      num_players: num_players
    }
    await templates_m.render_template 'templates/testing.mustache', {
        js_params: js_params
        js_deps: [
          '&jquery'
          'testing'
        ]
      },
      defer err, rendered_tmpl
    if err
      return (res.send err)

    return (res.send rendered_tmpl)

exports.TestingServer = TestingServer
exports.TestingStore = TestingStore