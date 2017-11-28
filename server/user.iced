crypto = require 'crypto'

sha256_hash = (s) ->
  shasum = crypto.createHash 'sha256'
  shasum.update s
  return shasum.digest 'base64'

class User
  @load_row = (row) ->
    uid = 'u' + row.id
    return new User uid, row.username, row.first_name, row.last_name

  @load_json = (json) ->
    return new User json.uid, json.username, json.first_name, json.last_name

  @dump_json = (user) ->
    return {
      uid: user.uid,
      username: user.username,
      first_name: user.first_name,
      last_name: user.last_name
    }

  constructor: (@uid, @username, @first_name, @last_name) ->

  toString: ->
    return JSON.stringify (User.dump_json @)

# in memory version for testing
class MemoryUserStore
  @is_valid_username = (username) ->
    return UserStore.is_valid_username username

  @hash_password = (password) ->
    return UserStore.hash_password password

  constructor: ->
    @_next_uid = 0
    @_users_by_uid = {}
    @_users_by_username = {}

  init: (cb) ->
    return cb null

  make_user: (username, pass_hash, info, cb) ->
    if username of @_users_by_username
      return cb {code: 'USER_EXISTS'}

    uid = 'u' + (@_next_uid++)
    user = new User uid, username, info.first_name, info.last_name
    @_users_by_username[username] = user
    @_users_by_uid[uid] = user

    user_copy = User.load_json (User.dump_json user)
    return cb null, user_copy

  get_user: (uid, cb) ->
    # TODO: check uid format
    ret = @_users_by_uid[uid] ? null
    return cb null, ret

  authorize: (username, pass_hash, cb) ->
    user = @_users_by_username[username]
    if not user? or user.password isnt pass_hash
      return cb null, null
    return cb null, (User.load_json (User.dump_json user))



class UserStore
  @is_valid_username = (username) ->
    unless (username.length > 0 and username.length <= 20)
      return false
    regex = /^[\w]+$/
    return regex.test username

  @hash_password = (password) ->
    return sha256_hash password

  constructor: (@_pool) ->
    # TODO: do we ever need to end the connection, or just hold it open indefinitely?

  _query: (q, data, cb) ->
    await @_pool.getConnection defer err, conn
    return cb err if err
    await conn.query q, data, defer err, result
    conn.release()
    return cb err if err
    return cb null, result

  init: (cb) ->
    COLUMNS = [
      ['id', 'INT(12) UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY']
      ['username', 'VARCHAR(64) NOT NULL UNIQUE KEY']
      ['password', 'VARCHAR(64) NOT NULL']
      ['first_name', 'VARCHAR(64) NOT NULL']
      ['last_name', 'VARCHAR(64) NOT NULL']
    ]

    col_str = ''
    for [name, type], idx in COLUMNS
      if idx > 0
        col_str += ', '
      col_str += "#{name} #{type}"

    query_str = "CREATE TABLE IF NOT EXISTS users (#{col_str})"
    await @_query query_str, {}, defer err, result
    return cb err if err
    return cb null

  make_user: (username, pass_hash, info, cb) ->
    data =
      username: username
      password: pass_hash
      first_name: info.first_name
      last_name: info.last_name

    await @_query 'INSERT INTO users SET ?', data, defer err, result
    if err
      if err.code is 'ER_DUP_ENTRY'
        return cb {code: 'USER_EXISTS'}
      return cb {code: 'UNKNOWN', info: err}
    uid = 'u' + result.insertId
    user = new User uid, username, info.first_name, info.last_name
    return cb null, user

  get_user: (uid, cb) ->
    uid_int = parseInt (uid.slice 1)
    args = [uid_int]

    await @_query 'SELECT * FROM users WHERE id=?', args, defer err, rows
    return cb err if err
    user = if rows.length > 0
      User.load_row rows[0]
    else
      null
    return cb null, user

  authorize: (username, pass_hash, cb) ->
    args = [username]

    await @_query 'SELECT * FROM users WHERE username=?', args, defer err, rows
    return cb err if err
    if rows.length == 0
      return cb null, null

    row = rows[0]
    if row.password != pass_hash
      return cb null, null
    return cb null, (User.load_row row)

exports.User = User
exports.UserStore = UserStore
exports.MemoryUserStore = MemoryUserStore