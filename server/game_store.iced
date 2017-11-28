

class GameStore
  constructor: (@_pool) ->

  init: (cb) ->
    COLUMNS = [
      # TODO: potential trouble with overflowing JS "int"s
      ['id', 'INT(12) UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY']
      ['type', 'VARCHAR(64) NOT NULL']
      ['game_json', 'BLOB']
    ]

    col_str = ''
    for [name, type], idx in COLUMNS
      if idx > 0
        col_str += ', '
      col_str += "#{name} #{type}"

    query_str = "CREATE TABLE IF NOT EXISTS games (#{col_str})"
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

  save: (game_type, game_json, cb) ->
    await @_query 'INSERT INTO games SET ?', {
      type: game_type
      game_json: (JSON.stringify game_json)
    }, defer err, result
    return cb err if err

    game_id = 'g' + result.insertId
    return cb null, game_id

  load: (game_id, cb) ->
    game_id_int = parseInt (game_id.slice 1)
    args = [game_id_int]

    await @_query 'SELECT * FROM games WHERE id=?', args, defer err, rows
    return cb err if err
    if rows.length is 0
      return cb null, null

    return cb null, {
      game_type: rows[0].game_type
      game_json: (JSON.parse rows[0].game_json)
    }


exports.GameStore = GameStore
