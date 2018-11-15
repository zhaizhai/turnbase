assert = require 'assert'
util_m = require 'shared/util.iced'

{TichuCardGraphics} = require 'games/tichu/tichu_card_graphics.iced'
{CardHand, CardArranger} = require 'canvas/cards/card_hand.iced'
{TurnIndicator} = require 'canvas/cards/four_player.iced'

window_m = require 'canvas/window.iced'
{Button, TextInfo, TextBox} = window_m
container_m = require 'canvas/container.iced'
{BorderFrame, HBox, VBox} = container_m

ui_helpers_m = require 'games/tichu/ui_helpers.iced'
{PhoenixPicker, WishPicker} = ui_helpers_m
logic = require 'games/tichu/tichu_logic.iced'
tichu_helpers_m = require 'games/tichu/tichu_helpers.iced'

modal_m = require 'client/lib/modal.iced'
{PointsDisplay} = require 'games/tichu/points_display.iced'
{TrickDisplay} = require 'games/tichu/trick_display.iced'

class CenterDisplay
  constructor: (@gc, @player_id) ->
    w = 5.5 * TichuCardGraphics.CARD_WIDTH
    h = 2.5 * TichuCardGraphics.CARD_HEIGHT

    @td = new TrickDisplay @gc, @player_id,
      {width: 0.7 * w, height: 0.7 * h}
    @elt = new TurnIndicator {
      width: w, height: h, center: @td
    }

    @wish_info = new TextInfo {}
    @vbox = new VBox {spacing: 5}, [@elt, @wish_info]

  update: ->
    directions = ['bottom', 'left', 'top', 'right']
    offset = (@gc.state().cur_turn - @player_id + 4) % 4
    @elt.set_primary directions[offset]
    lp = @gc.state().last_player
    if lp?
      offset = (lp - @player_id + 4) % 4
      @elt.set_secondary directions[offset]
    @td.update()

    wish = @gc.state().mahjong_wish
    if wish?
      wish_str = tichu_helpers_m.encode_val wish
    else
      wish_str = undefined
    @wish_info.set_info {
      Wish: wish_str
    }

class PlayControls
  constructor: (@gc, @player_id, @card_hand) ->
    @card_hand = @_arranger = null

    @tichu_button = new Button {
      text: 'Tichu!'
      bg_color: '#FFBBCB'
      handler: =>
        await @gc.submit_action 'tichu', [], defer err, res
        throw err if err
    }
    @_tichu_status_box = new TextBox {
      text: ''
      size: 12
      text_color: 'blue'
    }

    @play_button = new Button {
      text: 'Play',
      handler: (@_do_play.bind @)
    }
    @pass_button = new Button {
      text: 'Pass',
      handler: =>
        await @gc.submit_action 'pass', [], defer err, res
        throw err if err
    }

    @buttons = new VBox {spacing: 10}, [
      @_tichu_status_box, @tichu_button,
      @play_button, @pass_button
    ]
    @points_display = new PointsDisplay @gc, @player_id, {
      width: 80, size: 16, num_rows: 4
    }
    @_container = new HBox {spacing: 20}, [@buttons, @points_display.elt()]

  # TODO: this is kind of ugly, hopefully with a bit more careful
  # thought we can design a simpler bootstrapping process
  connect: (@card_hand) ->
    @_arranger = new CardArranger @card_hand, {
      toggle_on_click: true
    }
    @_arranger.activate()

  container: -> @_container

  _do_play: ->
    play_cards = []
    play_idxs = []
    for i in [0...@card_hand.num_cards()]
      info = @card_hand.get_attrs i
      unless info.raised
        continue
      play_cards.push info.card
      play_idxs.push info.orig_index

    phx_picker = new PhoenixPicker @gc
    wish_picker = new WishPicker @gc

    phx_val = if (phx_picker.has_phoenix play_cards)
      phx_picker.pick_phoenix play_cards
    else
      null
    wish = if (wish_picker.has_mahjong play_cards)
      wish_picker.get_wish()
    else
      null

    await @gc.submit_action 'play', [play_idxs, phx_val, wish],
      defer err, res
    throw err if err

  update_buttons: ->
    @points_display.update()

    if @gc.state().players[@player_id].is_out()
      # hide all buttons
      @_container.set_visible 0, false
      return
    else
      @_container.set_visible 0, true

    tichu_level = @gc.state().players[@player_id].tichu_level
    tichu_text = switch tichu_level
      when logic.GRAND then 'Grand Tichu'
      when logic.TICHU then 'Tichu'
      else null
    @_tichu_status_box.set_text tichu_text
    if tichu_level == logic.CAN_TICHU
      @buttons.set_visible 0, false
      @buttons.set_visible 1, true
    else
      @buttons.set_visible 1, false
      if tichu_text?
        @buttons.set_visible 0, true
      else
        @buttons.set_visible 0, false


class PlayController
  constructor: (@gc, @player_id, @root, @shared) ->
    @cd = new CenterDisplay @gc, @player_id
    @_ctrls = new PlayControls @gc, @player_id

  init: ->
    @shared.ui.init {
      ctrls: @_ctrls.container()
      display_pts: true
    }
    @shared.ui.update true

    @_ctrls.connect @shared.ui.card_hand()
    @_ctrls.update_buttons()

    @root.set_child 'center', @cd.vbox
    @cd.update()

  action: (data, cb) ->
    if data.action is 'tichu'
      await modal_m.flash {
        mesg: "#{data.username} calls Tichu!"
        duration: 1000
      }, defer()
      @_ctrls.update_buttons()
      # early return avoids resetting a player's hand if he tichud
      return cb()

    @shared.ui.update true
    @cd.update()
    @_ctrls.update_buttons()
    return cb()

  cleanup: ->
    @shared.ui.cleanup()
    @shared.scoreboard.update_score()

exports.PlayController = PlayController
