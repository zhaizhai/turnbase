window_m = require 'canvas/window.iced'
{Button, TextBox} = window_m
container_m = require 'canvas/container.iced'
{BorderFrame, HBox, VBox} = container_m

{MixinClass} = require 'canvas/mixin.iced'
{CanvElement} = require 'canvas/adapter.iced'
modal_m = require 'client/lib/modal.iced'

{TichuCardGraphics} = require 'games/tichu/tichu_card_graphics.iced'
{CardHand, CardArranger} = require 'canvas/cards/card_hand.iced'
logic = require 'games/tichu/tichu_logic.iced'


PassMat = MixinClass 'PassMat', [CanvElement],
  constructor: (@_cg) ->
    @_spacing = 15
    @height = @_cg.CARD_HEIGHT
    @width = @_cg.CARD_WIDTH * 3 + @_spacing * 2

    # array of {card, idx} or null
    @occupants = [null, null, null]
    @_onclick = null

  get_pass: ->
    to_pass = []
    for i in [0...3]
      if not @occupants[i]?
        return null
      to_pass.push @occupants[i].idx
    return to_pass

  get_occupant: (idx) ->
    if not @occupants[idx]?
      return null
    return @occupants[idx].idx

  # returns former occupant
  set: (idx, value) ->
    former = @get_occupant idx
    @occupants[idx] = value
    @set_dirty true
    return former

  click: (handler) ->
    @_onclick = handler

  mouse_evt: (evt, x, y) ->
    slot = @slot_from_coords x, y
    return if not slot?

    if evt is 'click' and @_onclick?
      return @_onclick slot

  slot_from_coords: (x, y) ->
    step = @_cg.CARD_WIDTH + @_spacing
    for i in [0...3]
      if (i * step <= x and x <= i * step + @_cg.CARD_WIDTH and
          0 <= y and y <= @_cg.CARD_HEIGHT)
        return i
    return null

  render: (ctx) ->
    x = 0
    for info in @occupants
      if not info?
        ctx.fillStyle = 'gray'
        ctx.fillRect x, 0, @_cg.CARD_WIDTH, @_cg.CARD_HEIGHT
      else
        {card, idx} = info
        @_cg.draw_card ctx, card, x, 0

      x += @_cg.CARD_WIDTH + @_spacing


class PassController
  constructor: (@gc, @player_id, @root, @shared) ->
    @card_hand = @_arranger = null
    @pass_mat = new PassMat TichuCardGraphics

    tichu_button = new Button {
      text: 'Tichu!'
      bg_color: '#0000DD'
      handler: =>
        await @gc.submit_action 'tichu', [], defer err, res
        throw err if err
    }

    submit = new Button {
      text: 'Pass'
      handler: =>
        to_pass = @pass_mat.get_pass()
        return if not to_pass?
        await @gc.submit_action 'pass', [to_pass], defer err, res
        throw err if err
      }

    @_tichu_status_box = new TextBox {
      text: ''
      size: 15
      text_color: 'blue'
    }
    @_ctrls = new VBox {spacing: 10}, [@_tichu_status_box, tichu_button, submit]

  pass_mat_handler: (mat_idx) ->
    existing = @pass_mat.get_occupant mat_idx
    if existing?
      hand_idx = @_arranger.get_idx_from_orig_index existing
      @card_hand.set_attr hand_idx, 'invisible', false

    sel = @_arranger.get_selection()
    if not sel?
      @pass_mat.set mat_idx, null
      return

    card = @gc.state().players[@player_id].cards[sel.orig_index]
    @card_hand.set_attr sel.idx, 'invisible', true
    @pass_mat.set mat_idx, {card: card, idx: sel.orig_index}
    @card_hand.set_all 'raised', false

  init: ->
    passed = @gc.state().to_pass[@player_id]
    if not passed?
      @pass_mat.click (@pass_mat_handler.bind @)

    @shared.ui.init {ctrls: @_ctrls}
    @root.set_child 'center', @pass_mat

    @card_hand = @shared.ui.card_hand()
    @_arranger = new CardArranger @card_hand, {
      toggle_on_click: true,
      multi_select: false
    }
    @_arranger.activate()

    @shared.ui.update()
    @_update_buttons()

  cleanup: ->
    @shared.ui.cleanup()
    for idx in [0...3]
      @pass_mat.set idx, null
    @_arranger.deactivate()

  action: (data, cb) ->
    if data.action is 'tichu'
      @reset_pass()
      @_update_buttons()
      await modal_m.flash {
        mesg: "#{data.username} calls Tichu!"
        duration: 1000
      }, defer()
      return cb()

    @shared.ui.update()
    @_update_buttons()

    if data.player_id isnt @player_id
      return cb()

    passed = @gc.state().to_pass[@player_id]
    if not passed?
      return cb()

    console.log 'passed', passed
    player = @gc.state().players[@player_id]
    for i in [0...3]
      idx = passed[i].get()
      @pass_mat.set i, {idx: idx, card: player.cards[idx]}
    @pass_mat.click null
    # @_submit.disable()
    return cb()

  _update_buttons: ->
    tichu_level = @gc.state().players[@player_id].tichu_level
    tichu_text = switch tichu_level
      when logic.GRAND then 'Grand Tichu'
      when logic.TICHU then 'Tichu'
      else null
    @_tichu_status_box.set_text tichu_text
    if tichu_level == logic.CAN_TICHU
      @_ctrls.set_visible 0, false
      @_ctrls.set_visible 1, true
    else
      @_ctrls.set_visible 0, true
      @_ctrls.set_visible 1, false

    passed = @gc.state().to_pass[@player_id]
    if not passed?
      @_ctrls.set_visible 2, true
    else
      @_ctrls.set_visible 2, false

  # called when someone tichus before all have passed
  reset_pass: ->
    for i in [0,1,2]
      @pass_mat.set i, null
    @pass_mat.click (@pass_mat_handler.bind @)
    @card_hand.set_all 'invisible', false
    @card_hand.set_all 'raised', false
    @_update_buttons()



exports.PassController = PassController
