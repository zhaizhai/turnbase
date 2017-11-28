{$ajax} = require 'client/lib/http_util.iced'
html_util_m = require 'client/lib/html_util.iced'

class PlayersList
  PLAYERS_TMPL = '''
  <div class="players-container">
    <div class="region-header">Players</div>
    <div class="players-list"></div>
  </div>
  '''
  REQ_BOT_TMPL = '''
  <button class="request-bot-button standard-button">
    Request bot
  </button>
  '''

  constructor: (@table_info, @_has_bots = false) ->
    @tid = @table_info.tid
    @_elt = $ PLAYERS_TMPL
    @update()
    @table_info.on 'users-changed', =>
      @update()

  elt: -> @_elt

  update: ->
    list = @_elt.find '.players-list'
    list.empty()
    for i in [0...@table_info.num_players()]
      user = @table_info.get_user i
      if user?
        list.append ($ "<div>#{user.username}</div>")
      else
        row = ($ "<div><span>[empty]</span></div>")
        if @_has_bots
          row.append (@_make_req_button i)
        list.append row

  _make_req_button: (player_id) ->
    button = ($ REQ_BOT_TMPL).click =>
      await @_req_bot player_id, defer err
      # TODO: maybe disable button while request in progress
    return button

  _req_bot: (player_id, cb) ->
    await $ajax.get "/table/#{@tid}/request_bot", {
      bot_player_id: player_id
    }, defer err, res
    console.log 'request bot', err, res
    if err then return cb err
    return cb null

exports.PlayersList = PlayersList
