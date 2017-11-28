{$ajax} = require 'client/lib/http_util.iced'

class PlayerTab
  constructor: (@tid, @player_id) ->
    @_iframe = $ "<iframe width=\"1100\" height=\"1000\" src=\"/table/#{tid}?player_id=#{@player_id}\"></iframe>"

    @_tab = ($ "<div>Player #{@player_id}</div>").css {
      display: 'table-cell'
    }

    @hide()

  hide: ->
    @_iframe.css 'display', 'none'
    @_tab.css 'border-style', ''

  show: ->
    @_iframe.css 'display', ''
    @_tab.css 'border-style', 'solid'

  tab: -> @_tab

  iframe: -> @_iframe


class TestView
  constructor: (@tid, @num_players) ->
    @_selected = null
    @_players = []

    for i in [0...num_players]
      pt = new PlayerTab tid, i
      tab = pt.tab()
      ($ '#tabs').append tab
      @_players.push pt
      ($ '#iframe-display').append pt.iframe()

      do (i) =>
        tab.click =>
          @select i

  select: (player_id) ->
    if @_selected?
      @_players[@_selected].hide()
    @_selected = player_id
    pt = @_players[@_selected]
    pt.show()


window.onload = ->
  {uid, tid, num_players} = window.TEMPLATE_PARAMS

  list_url = (document.URL.replace /\?.*$/, '')
  list_url = (list_url.replace /\/+$/, '') + '/list'
  SAVE_TMPL = """
  <div>
    <div>
      Save game state below. You can load previously saved game states
      at <a href=\"#{list_url}\" target=\"_blank\">#{list_url}</a>. Note:
      if you make changes to game logic, in some cases old saved states will
      fail to load properly.
    </div>
    <textarea style=\"width: 300px; height: 90px;\"
              placeholder=\"Describe the current game state...\"></textarea>
    <button>Save</button><span class=\"save-status\"></span>
  </div>
  """
  save_elt = $ SAVE_TMPL
  description = save_elt.find 'textarea'
  save_button = save_elt.find 'button'
  save_status = save_elt.find '.save-status'

  save_button.click ->
    save_status.text 'Saving...'
    $ajax.post '/testing/save', {
      tid: tid, description: description.val()
    }, (err, res) ->
      console.log 'save', err, res
      status_txt = if err
        "Error: #{JSON.stringify err}"
      else
        "Saved!"
      save_status.text status_txt

  ($ '#save-region').append save_elt

  tv = new TestView tid, num_players
  tv.select 0