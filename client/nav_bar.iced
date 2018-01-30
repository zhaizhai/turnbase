{$ajax} = require 'client/lib/http_util.iced'
{Modal} = require 'client/lib/modal.iced'

window.NavBar = class NavBar
  TP = window.TEMPLATE_PARAMS
  NAV_OPTS =
    leave:
      text: 'Leave game'
      onclick: ->
        tid = TP.tid
        await $ajax.post "/table/#{tid}/kick", {
          player_id: TP.player_id
        }, defer err, res
        console.log 'kick result', err, res
        # TODO: handle error
        nav_url = '/'
        if TP.game_type?
          nav_url += "\##{TP.game_type}"
        window.location.href = nav_url

    home:
      text: 'Home'
      onclick: ->
        window.location.href = '/'

    rules:
      text: 'Rules'
      onclick: ->
        container = $('<div></div>').css {
          'text-align': 'left'
          'font-size': '12px'
        }
        modal = new Modal $(document.body), container, {
          popout_color: '#bbbbbb', grayout: 0.7
        }

        container.append $('<div></div>').css({
          'overflow-y': 'scroll'
          height: '400px'
          'background-color': '#eeeeee'
          padding: '5px'
        }).append(markdown.toHTML TP.rules_md)

        dismiss = $('<button>Got it!</button>').css({
          'margin-top': '8px', 'font-size': '20px'
        }).click =>
          modal.hide()
        container.append dismiss

        modal.show()


  constructor: (opts...) ->
    @_elt = $ '''<div class="nav-bar"></div>'''
    for opt in opts
      {text, onclick} = NAV_OPTS[opt]
      nav_elt = $ '<a href="" class="nav-bar-link"></a>'
      do (onclick) =>
        nav_elt.text(text).click (e) =>
          e.preventDefault()
          onclick()
      @_elt.append nav_elt

    @_elt.append ($ "<span class=\"nav-bar-status\">Logged in as <b>#{TP.username}</b></span>")
    logout = $('<a href="" class="nav-bar-link nav-bar-signout">Sign out</a>').click =>
      console.log 'logging out...'
      win.location.href = '/logout'
    @_elt.append logout

    # TODO: hack for now
    old_onload = window.onload
    window.onload = ->
      $(document.body).prepend @_elt
      old_onload?()
