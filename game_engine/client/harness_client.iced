{GameClient} = require 'game_engine/client/game_client.iced'
{OpStream} = require 'game_engine/client/op_stream.iced'

{LongPollClient} = require 'client/lib/poll_client.iced'
{ChatClient} = require 'client/chat.iced'
{PlayersList} = require 'client/players.iced'
{TableInfo} = require 'client/table_info.iced'

util_m = require 'shared/util.iced'
{T} = require 'shared/T/T.iced'
{make_elt} = require 'client/lib/html_util.iced'

{make_display} = require 'game_engine/client/harness_elts.iced'


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
      args = []
      for t, idx in types
        arg = @_inputs[idx].val()
        [arg, error] = @_parse_arg t, arg, idx
        if error?
          @set_status error
          return
        args.push arg

      console.log "action #{name}:", args
      gc.submit_action name, args, (err, res) =>
        console.log "from action #{name}:", err, res
        if err
          @set_status "#{JSON.stringify err}"
        else if res isnt 'ok'
          @set_status "#{JSON.stringify res}"

  _parse_arg: (t, arg, idx) ->
    # TODO: only handle ints, strings, and booleans for now
    arg = arg.trim()
    if t is T.Integer
      arg = parseInt arg
      if isNaN arg
        return [null, "Argument #{idx} (= #{arg}) is not an integer."]
      return [arg, null]

    if t is T.Boolean
      if arg is "true"
        return [true, null]
      else if arg is "false"
        return [false, null]
      return [null, "Argument #{idx} (= #{arg}) is not a boolean."]

    if t is T.String
      return [arg, null]

    throw new Error "Don't know how to handle type #{t._name}!"

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

  base_display = null
  overlay_display = null
  init_display = (overlay_obj, base_obj) ->
    toplevel = $ '#game-region'
    elt = $ TMPL
    toplevel.append elt

    # TODO: update mode/state terminology
    base_display = make_display base_obj
    elt.find('div.spec-state-info').append base_display.elt()
    overlay_display = make_display overlay_obj
    elt.find('div.spec-mode-info').append overlay_display.elt()

  on_refresh = ->
    base_obj = {}
    overlay_obj = {}
    for k, v of gc.state()
      if k of game_spec.base
        base_obj[k] = v
      else
        overlay_obj[k] = v

    toplevel = $('#game-region')
    if not base_display?
      init_display overlay_obj, base_obj
    else
      overlay_display.update overlay_obj
      base_display.update base_obj

    toplevel.find('div.spec-mode-name').text gc.mode_name()
    actions = toplevel.find('div.test-controls')
    actions.empty()
    actions.append (make_action_display game_spec, gc)

  mode_handlers = {}
  for name, mode of game_spec.modes
    mode_handlers[name] =
      init: -> on_refresh()
      action: -> on_refresh()
      cleanup: ->
  await gc.init mode_handlers, defer err
  throw err if err

  lpc.run()
