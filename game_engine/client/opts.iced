require 'games/bundles/master_bundle.iced'
html_util_m = require 'client/lib/html_util.iced'

from_raw = (raw_opt) ->
  switch raw_opt.type
    when 'select'
      return new Select raw_opt.choices, raw_opt.default_choice
    else
      throw new Error "Unrecognized type #{raw_opt.type}"

make_opt_elts = (raw_opts) ->
  opt_elts = []
  choices = {}
  for line in raw_opts
    opt_elt = $ '<div></div>'
    for x in line
      if typeof x is 'string'
        opt_elt.append ($ "<span>#{x}</span>")
      else
        [name, opt] = x
        opt = from_raw opt
        choices[name] = opt
        opt_elt.append opt.elt()
    opt_elts.push opt_elt
  return {opt_elts, choices}

class Select
  constructor: (@_choices, default_choice = null) ->
    @_elt = (html_util_m.make_select @_choices)
    if default_choice?
      selector = 'option[value="' + default_choice + '"]'
      (@_elt.find selector).attr 'selected', true

  elt: -> @_elt
  val: ->
    choice = @_elt.find(':selected').text()
    return @_choices[choice]

exports.GAME_OPTS = {}
for name, spec of window.ALL_GAMES
  opts = spec.setup.options ? []
  exports.GAME_OPTS[name] = make_opt_elts opts
