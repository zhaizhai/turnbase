{GameClient} = require 'game_engine/client/game_client.iced'
{OpStream} = require 'game_engine/client/op_stream.iced'

{LongPollClient} = require 'client/lib/poll_client.iced'
{ChatClient} = require 'client/chat.iced'
{PlayersList} = require 'client/players.iced'
{TableInfo} = require 'client/table_info.iced'

{T} = require 'shared/T/T.iced'
{make_elt} = require 'client/lib/html_util.iced'



make_display = (x) ->
  if not x?
    return $ '<div>null</div>'
  if typeof x in ['string', 'number', 'boolean']
    return $ "<div>#{x}</div>"
  if T.is_masked x
    return ($ "<div></div>").text "<masked>"

  if x instanceof Array
    return (new ArrayDisplay x).elt()
  return (new StructDisplay x).elt()

class ArrayDisplay
  TMPL = '''
  <div class="spec-container">
    <div class="spec-array-header">
      <div class="standard-table-cell">
        <div class="spec-array-dropdown">+</div>
      </div>
      <div class="spec-header-text standard-table-cell"></div>
    </div>
    <div class="spec-table-container">
      <table class="spec-array-table"></table>
    </div>
  </div>
  '''
  constructor: (arr, name = null) ->
    @_elt = $ TMPL
    @_header = (@_elt.find '> > .spec-header-text')
    header_text = (if name? then "#{name}:" else "<array>")
    header_text += " [#{arr.length}]"
    @_header.text header_text

    @_table = (@_elt.find '> > .spec-array-table')
    for x, idx in arr
      td = $ '<td></td>'
      td.append (make_display x)
      li = $ "<tr><td>#{idx}:</td></tr>"
      li.append td
      @_table.append li
    @_table_container = (@_elt.find '> .spec-table-container')
    @_table_container.hide()

    @_shown = false
    @_dropdown = (@_elt.find '> > > .spec-array-dropdown')

    if arr.length is 0
      @_dropdown.html ''
      return

    (@_elt.find '> .spec-array-header').click =>
      @_shown = not @_shown
      if @_shown
        @_dropdown.html '&ndash;'
      else
        @_dropdown.html '+'
      @_table_container.slideToggle 300

  elt: -> @_elt


class StructDisplay
  TMPL = '''
    <div></div>
  '''
  ITEM_TMPL = '''
    <div class="spec-container">
      <div class="spec-struct-key"></div>
      <div class="spec-struct-value"></div>
    </div>
  '''

  constructor: (obj) ->
    keys = []
    for k of obj
      keys.push k
    keys.sort()

    @_elt = $ TMPL

    for k, v of obj
      # TODO: show access somehow
      if k is '_access' then continue
      if typeof v is 'function' then continue

      if v instanceof Array
        @_elt.append (new ArrayDisplay v, k).elt()
        continue

      item = $ ITEM_TMPL
      (item.find '.spec-struct-key').text "#{k}:"
      (item.find '.spec-struct-value').append (make_display v)
      @_elt.append item

  elt: -> @_elt




class ActionDisplay
  TMPL = '''
    <div class="spec-action-display">
      <div class="spec-action-name">{{name}}</div>
      <div class="spec-action-input-area"></div>
      <button class="spec-action-submit">Submit</button>
      <div class="spec-action-status"></div>
    </div>
  '''
  INPUT_TMPL = '''
    <div>
      <span class="spec-action-arg">{{name}}</span>
      <input class="spec-action-input"></input>
    </div>
  '''

  constructor: (gc, name, args, types) ->
    if args.length isnt types.length
      console.log 'args', args
      console.log 'types', types
      throw new Error "args and types mismatch!"
    @_elt = make_elt TMPL, {name}

    @_inputs = []
    for _, idx in types
      input = make_elt INPUT_TMPL, {name: args[idx]}
      (@_elt.find 'div.spec-action-input-area').append input
      @_inputs.push (input.find 'input')

    (@_elt.find 'button.spec-action-submit').click =>
      # TODO: only handle ints and strings for now
      args = []
      for t, idx in types
        arg = @_inputs[idx].val().trim()
        if t is T.Integer
          arg = parseInt arg
        args.push arg

      console.log "action #{name}:", args
      gc.submit_action name, args, (err, res) =>
        console.log "from action #{name}:", err, res
        if err
          @set_status "#{JSON.stringify err}"
        else if res isnt 'ok'
          @set_status "#{JSON.stringify res}"

  set_status: (text) ->
    console.log 'setting status', text
    status_area = (@_elt.find '.spec-action-status')
    status_area.stop true
    status_area.css {opacity: 1}
    status_area.text text
    status_area.animate {opacity: 1}, 200
    status_area.animate {opacity: 0.5}, 1000

  elt: -> @_elt





STRIP_COMMENTS = /((\/\/.*$)|(\/\*[\s\S]*?\*\/))/mg
ARGUMENT_NAMES = /([^\s,]+)/g
param_names = (func) ->
  s = func.toString()
  s = s.replace STRIP_COMMENTS, ''
  s = s.slice ((s.indexOf '(') + 1), (s.indexOf ')')
  result = (s.match ARGUMENT_NAMES) ? []
  return result

make_action_display = (spec, gc) ->
  mode = spec.modes[gc.mode_name()]
  ret = $ '<div></div>'

  for k, func of mode.actions
    action_spec = func()
    args = param_names func
    console.log 'spec', action_spec, 'args', args
    ad = new ActionDisplay gc, k, args, action_spec.types
    ret.append ad.elt()
  return ret



exports.setup = (game_spec) ->
  TMPL = '''
  <div>
    <div class="test-info">
      <div class="spec-mode-info">
        <div class="spec-mode-name"></div>
      </div>
      <div class="spec-state-info"></div>
    </div>
    <div class="test-controls"></div>
  </div>
  '''

  {tid, player_id, game_type} = TEMPLATE_PARAMS
  lpc = new LongPollClient "/table/#{tid}/poll"
  op_stream = new OpStream lpc

  table_info = new TableInfo tid, player_id, lpc
  players_list = new PlayersList table_info, false
  ($ '#right-column').append players_list.elt()

  chat_client = new ChatClient lpc, player_id,
    "/table/#{tid}/chat", "#{tid}:chat"
  ($ '#right-column').append chat_client.elt()

  window.gc = gc = new GameClient game_spec,
    table_info, player_id, op_stream
  gc.on 'log-mesg', (mesg) ->
    chat_client.add_message mesg, 'bold'

  on_refresh = ->
    container = $ '#game-region'
    container.empty()
    elt = $ TMPL
    (elt.find 'div.spec-mode-name').text gc.mode_name()

    base_obj = {}
    overlay_obj = {}
    for k, v of gc.state()
      if k of game_spec.base
        base_obj[k] = v
      else
        overlay_obj[k] = v

    # TODO: update mode/state terminology
    (elt.find 'div.spec-mode-info').append (make_display overlay_obj)
    (elt.find 'div.spec-state-info').append (make_display base_obj)
    (elt.find 'div.test-controls').append (make_action_display game_spec, gc)
    container.append elt

  mode_handlers = {}
  for name, mode of game_spec.modes
    mode_handlers[name] =
      init: -> on_refresh()
      action: -> on_refresh()
      cleanup: ->
  await gc.init mode_handlers, defer err
  throw err if err

  lpc.run()
