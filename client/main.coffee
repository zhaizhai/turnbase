require 'games/bundles/master_bundle.iced'
# populates window.ALL_GAMES
util_m = require 'shared/util.iced'

{LongPollClient} = require 'client/lib/poll_client.iced'
{$ajax} = require 'client/lib/http_util.iced'
{CreateTable} = require 'client/create_table.iced'
html_util_m = require 'client/lib/html_util.iced'

{ChatClient} = require 'client/chat.iced'

class SelectGame
  GAME_BLOCK_TMPL = '''
  <div class="game-block"><span class="vertical-align">{{name}}</span></div>
  '''

  constructor: (@uid, @poll_client) ->
    @_buttons = {}
    @_selected = null
    @_latest_table_list = []

    games_grid = []
    ct = 0
    for name, game of ALL_GAMES
      if ct % 2 == 0
        games_grid.push []
      ct += 1

      e = html_util_m.make_elt GAME_BLOCK_TMPL, {
        name: game.display_name
      }
      do (name) =>
        e.click =>
          @_select name

      @_buttons[name] = e
      (util_m.last games_grid).push e

    console.log 'games grid', games_grid
    @_elt = html_util_m.make_table games_grid

  _select: (game_type) ->
    @_selected = game_type
    for g, e of @_buttons
      if g is game_type
        e.addClass 'game-block-selected'
      else
        e.removeClass 'game-block-selected'

    ct = new CreateTable @uid, ALL_GAMES[game_type]
    ($ '#create-table-region').empty()
    ($ '#create-table-region').append ct.elt()
    @refresh_table_list()

  elt: -> @_elt

  refresh_table_list: ->
    container = $ '#table-list'
    container.empty()

    list_info = []
    for info in @_latest_table_list
      if info.table_type is @_selected
        list_info.push info
    tl = new TableList @uid, list_info
    container.append tl.elt()

  init: ->
    @poll_client.register_handler 'table-list', @uid, -1,
      (table_list_info) =>
        console.log 'table list update', table_list_info
        @_latest_table_list = table_list_info
        @refresh_table_list()


class TableList
  TMPL = '''
  <div class="table-list-container">
    <div class="region-header table-list-header">Tables</div>
  </div>
  '''
  NO_TABLES = '''<div class="no-tables">No tables.</div>'''

  constructor: (@uid, @table_list_info) ->
    @_elt = $ TMPL
    for info in @table_list_info
      can_watch = info.party_mode
      table_disp = new TableDisplay @uid, info.tid, info.users, can_watch
      @_elt.append table_disp.elt()

    if @table_list_info.length is 0
      @_elt.append ($ NO_TABLES)

  elt: -> @_elt


class TableDisplay
  TMPL = '''
  <div class="table-display">
    <div class="tid"></div>
    <div class="join-container"></div>
  </div>
  '''

  constructor: (@uid, @tid, @users, can_watch = false) ->
    @_elt = $ TMPL

    display_tid = (parseInt (@tid.slice 1)) + 1
    (@_elt.find 'div.tid').text "Table \##{display_tid}"

    for user, player_id in users
      button = @make_join_button user, player_id
      button.css 'display', 'table-cell'
      (@_elt.find 'div.join-container').append button

    if can_watch
      watch_button = html_util_m.make_button("Watch").css({
        'margin-left': 10
      }).click =>
        window.location.href = "/table/#{@tid}?player_id=-1"
      (@_elt.find 'div.join-container').append watch_button

  make_join_button: (user, player_id) ->
    button_text = if user? then "#{user.username}" else "Seat #{player_id}"
    join_button = html_util_m.make_button button_text

    if user? and user.uid isnt @uid
      return join_button.attr 'disabled', true

    join_button.click =>
      await $ajax "/table/#{@tid}/join",
        {tid: @tid, player_id: player_id},
        'post', defer err, resp
      if err
        throw new Error 'todo: handle error'
      if not resp.success
        # TODO: other error possibilities?
        return alert "player id #{player_id} is already taken"
      window.location.href = "/table/#{@tid}?player_id=#{player_id}"
    return join_button

  elt: -> @_elt

class ChatArea
  CHAT_AREA_TMPL = '''
  <div class="chat-area">
    <div class="chat-header region-header">Users online</div>
    <div class="user-list"></div>
  </div>
  '''

  constructor: (@uid, @poll_client) ->
    @_elt = html_util_m.make_elt CHAT_AREA_TMPL
    @_users = []

    @_chat_client = new ChatClient @poll_client, @uid,
      "/chat", "global:chat"
    @_elt.append @_chat_client.elt()

  elt: -> @_elt

  update: ->
    list_elt = @_elt.find '.user-list'
    list_elt.empty()
    for username in @_users
      list_elt.append ($ "<div>#{username}</div>")

  init: ->
    @poll_client.register_handler 'user-list', @uid, -1,
      (user_list_info) =>
        console.log 'user list update', user_list_info
        @_users = []
        for uid, user of user_list_info
          @_users.push user.username
        @_users.sort util_m.lexicographically
        @update()

window.onload = ->
  uid = window.TEMPLATE_PARAMS.uid
  game_type =

  poll_client = new LongPollClient '/table_list/poll'

  sg = new SelectGame uid, poll_client
  ($ '#select-game-region').append sg.elt()

  sg.init()
  game_names = (name for name of ALL_GAMES)
  default_game = if window.location.hash
    window.location.hash.slice(1)
  else
    game_names[0]
  sg._select default_game

  ca = new ChatArea uid, poll_client
  ($ '.top-right-panel').append ca.elt()
  ca.init()

  ($ '.chat-input').attr 'tabindex', 1
  poll_client.run()
