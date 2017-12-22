
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
