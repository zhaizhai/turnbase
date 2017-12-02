assert = require 'assert'
util_m = require 'shared/util.iced'

{T, struct} = require 'shared/T/T.iced'
{V} = require 'shared/T/validation.iced'

exports.T = T
exports.V = V
exports.struct = struct

exports.option = (tmpl, params) ->
  ret = []
  s = tmpl
  while true
    pos = s.indexOf '%{'
    break if pos is -1

    if pos > 0
      ret.push s.slice 0, pos
    s = s.slice (pos + 2)

    close = s.indexOf '}'
    interp = s.slice 0, close

    if not params[interp]?
      throw new Error "Option parameter #{interp} is missing a specification!"

    ret.push [interp, params[interp]]
    s = s.slice (close + 1)
  ret.push s
  return ret

exports.select = (choices, default_choice = null) ->
  return {
    type: 'select'
    choices: choices
    default_choice: default_choice
  }

class GameMode
  RESERVED_FIELDS = [
    'LEAVE_MODE', 'ENTER_MODE', 'LOG' # TODO
  ]

  @create = (name, base, fields) ->
    for f in RESERVED_FIELDS
      if f of fields
        throw new Error "Reserved field #{f} not allowed"

    struct_fields = {}
    actions = {}
    for k, v of fields
      if typeof v is 'function' and not v.type?
        actions[k] = v
      else
        struct_fields[k] = v

    for k, v of base
      struct_fields[k] = v

    init = ->
    if fields.init?
      init = fields.init
      if typeof init isnt 'function'
        throw new Error "init must be a function"

    # console.log 'struct fields are', struct_fields

    mode_struct = struct name, struct_fields

    return new GameMode {
      name: name, init: init, struct: mode_struct
      actions: actions
    }

  constructor: (opts) ->
    {@name, @init, @struct, @actions} = opts


class Turnbase
  constructor: (@game_name) ->
    @_base = null
    @_modes = {}
    @_setup = null

  state: (fields) ->
    @_base = fields

  setup: (opts) ->
    DEFAULTS =
      options: null
      defaults: {}
    REQUIRED = ['init']

    for k, v of DEFAULTS
      opts[k] ?= v
    if opts.options?
      for opt_spec in opts.options
        for part in opt_spec
          if typeof part is 'string'
            continue
          [field_name, chooser] = part
          opts.defaults[field_name] = chooser.default_choice

    for k in REQUIRED
      if not k of opts
        throw new Error "Missing required option #{k}"
    @_setup = opts

  mode: (name, fields) ->
    assert @_base?, "Must specify base before modes!"
    mode = GameMode.create name, @_base, fields
    @_modes[name] = mode

  main: (fn) ->
    @mode 'Main', {
      start: ->
        types: []
        validate: -> V.r true
        execute: ->
          fn.apply @, []
    }

  # Extends a game spec with setup and mode info. Note: this is only
  # meant to be used internally within the framework.
  extend_spec: (spec) ->
    assert @_setup?
    assert @_modes.Main?

    spec.base = @_base
    spec.setup = @_setup
    spec.modes = @_modes


g_turnbase = null
exports.create = (name) ->
  g_turnbase = new Turnbase name
exports.get = ->
  return g_turnbase

for method in ['state', 'setup', 'mode', 'main']
  do (method) ->
    exports[method] = (args...) ->
      g_turnbase[method] args...