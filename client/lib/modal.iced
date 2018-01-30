assert = require 'assert'

exports.Modal = class Modal
  DEFAULTS =
    popout_color: '#ddddbb'
    grayout: 0.5
  constructor: (@container, inner, opts = {}) ->
    for k, v of DEFAULTS
      opts[k] ?= v

    @_elt = ($ '<div></div>').css {
      width: "#{@container.width()}px"
      height: "#{@container.height()}px"
      position: 'absolute'
      top: '0px'
    }

    # TODO: adjust z-index according to parent?
    @gray_out = ($ '<div></div>').css {
      opacity: opts.grayout
      'background-color': 'black'
      'z-index': 100
      width: @_elt.width()
      height: @_elt.height()
      position: 'absolute'
    }

    centerer = ($ '<div></div>').css {
      'z-index': 101
      width: @_elt.width()
      height: @_elt.height()
      position: 'absolute'
    }

    @pop_up = ($ '<div></div>').css {
      position: 'absolute'
      top: '50%', left: '50%'
      transform: 'translate(-50%, -50%)'

      'background-color': opts.popout_color
      'border-radius': 6
      padding: 10

      'text-align': 'center'
      'font-size': 24
    }
    @pop_up.append inner

    centerer.append @pop_up
    @_elt.append @gray_out
    @_elt.append centerer
    # make sure we're inside a position: relative
    @_elt = $('<div></div>').css({position: 'relative'}).append(@_elt)

  show: ->
    @container.prepend(@_elt)

  hide: ->
    @_elt.detach()


exports.prompt = (opts, cb) ->
  {validator, mesg} = opts
  validator ?= -> {is_valid: true, mesg: null}

  TMPL = '''<div>
    <div class="prompt-text"></div>
    <input type="text"></input>
    <div class="error-text"></div>
    <button class="button-ok">OK</button>
    <button class="button-cancel">Cancel</button>
  </div>'''

  elt = $ TMPL
  modal = new Modal ($ '#game-region'), elt

  elt.find('div.prompt-text').text opts.mesg
  input = elt.find('input')
  elt.find('button.button-ok').click =>
    val = input.val()
    {is_valid, mesg} = validator val
    assert is_valid?

    if not is_valid
      err_text = elt.find('div.error-text')
      err_text.stop true
      err_text.css {opacity: 1, color: 'red', 'font-size': '12px'}
      err_text.text mesg
      err_text.animate {opacity: 1}, 200
      err_text.animate {opacity: 0.25}, 1000
      return
    modal.hide()
    cb val
  elt.find('button.button-cancel').click =>
    modal.hide()
    cb null
  modal.show()


exports.choice = (opts, cb) ->
  # choices = list of strings
  {choices, mesg} = opts
  TMPL = '''<div>
    <div class="prompt-text"></div>
    <div class="radio-container"></div>
    <button class="button-ok">OK</button>
    <button class="button-cancel">Cancel</button>
  </div>'''

  elt = $ TMPL
  modal = new Modal ($ '#game-region'), elt

  elt.find('div.prompt-text').text mesg
  radio_container = elt.find('.radio-container')
  for choice, idx in choices
    input_elt = $ """<div>
      <input type=\"radio\" id=\"choice#{idx}\" name=\"radio-modal\" value=\"#{idx}\"/>
      <label for=\"choice#{idx}\">#{choice}<\label>
    </div>"""
    input_elt.css {fontSize: 16}
    radio_container.append input_elt

  elt.find('button.button-ok').click =>
    val = radio_container.find('input[name=radio-modal]:checked').val()
    val = parseInt val
    modal.hide()
    cb val
  elt.find('button.button-cancel').click =>
    modal.hide()
    cb null
  modal.show()


exports.confirm = (opts, cb) ->
  {mesg} = opts
  TMPL = '''<div>
    <div class="prompt-text"></div>
    <button class="button-ok">OK</button>
    <button class="button-cancel">Cancel</button>
  </div>'''

  elt = $ TMPL
  modal = new Modal ($ '#game-region'), elt

  elt.find('div.prompt-text').text opts.mesg
  elt.find('button.button-ok').click =>
    modal.hide()
    cb true
  elt.find('button.button-cancel').click =>
    modal.hide()
    cb false
  modal.show()


exports.flash = (opts, cb) ->
  {mesg, duration} = opts
  elt = ($ "<div>#{mesg}</div>").css {
    'font-size': '30px'
  }
  modal = new Modal ($ '#game-region'), elt
  modal.show()
  await setTimeout defer(), duration
  modal.hide()
  return cb()
