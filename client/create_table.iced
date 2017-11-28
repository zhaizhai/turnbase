assert = require 'assert'
{$ajax} = require 'client/lib/http_util.iced'
html_util_m = require 'client/lib/html_util.iced'

{GAME_OPTS} = require 'game_engine/client/opts.iced'

class CreateTable
  TMPL = '''
  <div>
    <div class="region-header create-table-header">
      New table
    </div>
    <div class="game-options"></div>
    <button class="standard-button">Create</button>
  </div>
  '''

  constructor: (@uid, @game_spec) ->
    assert @game_spec?
    console.log 'spec', @game_spec
    opts_info = GAME_OPTS[@game_spec.name]

    @_elt = $ TMPL
    @_choices = opts_info.choices

    for elt in opts_info.opt_elts
      (@_elt.find 'div.game-options').append elt

    (@_elt.find 'button').click =>
      @_create false

    if @game_spec.spectator?
      party_button = $ '<button class="standard-button">Create in party mode</button>'
      party_button.click =>
        @_create true
      @_elt.append party_button

  _create: (party_mode) ->
    initial_data = {}
    for k, opt of @_choices
      initial_data[k] = opt.val()

    table_opts =
      table_type: @game_spec.name
      party_mode: party_mode
      initial_data: initial_data

    await $ajax '/table_list/create_table',
      table_opts, 'post', defer err, resp
    if err
      throw new Error 'todo: handle create_table error'

  elt: -> @_elt

exports.CreateTable = CreateTable
