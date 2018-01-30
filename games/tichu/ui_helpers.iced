assert = require 'assert'

window_m = require 'canvas/window.iced'
{TextInfo, TextBox} = window_m
container_m = require 'canvas/container.iced'
{BorderFrame, HBox, VBox} = container_m

logic = require 'games/tichu/tichu_logic.iced'
tichu_helpers_m = require 'games/tichu/tichu_helpers.iced'
{encode_val, decode_val} = tichu_helpers_m

{TichuCardGraphics} = require 'games/tichu/tichu_card_graphics.iced'
{CardHand, HiddenCardHand, CardArranger} = require 'canvas/cards/card_hand.iced'
{PointsDisplay} = require 'games/tichu/points_display.iced'
{OpponentHands} = require 'canvas/cards/four_player.iced'


class PhoenixPicker
  constructor: (@gc) ->

  has_phoenix: (to_play) ->
    phoenix_idx = null
    for card in to_play
      if card.suit is 'phoenix'
        return true
    return false

  # returns picked value or null if invalid
  pick_phoenix: (to_play) ->
    phoenix_idx = null
    phoenix_idx = null
    for card, idx in to_play
      if card.suit is 'phoenix'
        phoenix_idx = idx

    assert phoenix_idx?
    last_play = @gc.state().cur_trick.last_play()
    console.log 'inferring phoenix', to_play, last_play
    valid_vals = logic.valid_phoenix_values to_play, last_play

    if valid_vals.length is 0
      console.log 'invalid play', to_play
      return null

    else if valid_vals.length is 1
      return valid_vals[0]

    else if valid_vals.length is 2
      [v1, v2] = valid_vals
      [s1, s2] = (encode_val v for v in valid_vals)
      desired = prompt "Enter phoenix value (#{s1} or #{s2})", s2
      # user hit cancel, so don't play
      # TODO: possibly this should be distinguished from invalid value
      if not desired?
        return null
      d = decode_val desired
      if d not in [v1, v2]
        alert 'Invalid phoenix choice!'
        return null
      return d

    else
      console.log 'WARNING: unexpectedly got 3+ phoenix values'
      return null


class WishPicker
  constructor: (@gc) ->

  has_mahjong: (to_play) ->
    mahjong_idx = null
    for card in to_play
      if card.suit is 'mahjong'
        return true
    return false

  # returns picked value or null if canceled
  get_wish: ->
    # ask for wish
    desired = prompt "Enter wish (2-A). Leave blank for no wish.", ""
    # user hit cancel, so don't play
    if not desired?
      return null
    d = decode_val desired
    unless 2 <= d <= 14
      return null
    return d


class PlayerInfo
  constructor: (@gc, @player_id, opts) ->
    opts ?= {}
    @_user_info = new TextBox {
      text: ''
      size: 12
    }
    @_tichu_status = new TextBox {
      text: ''
      size: 12
      text_color: 'blue'
    }
    @_points_display = if opts.points_display
      new PointsDisplay @gc, @player_id, {
        width: 80
        size: 14
        num_rows: 4
      }
    else
      null

    @_elt = new VBox {spacing: 15}, [@_user_info]
    if @_points_display?
      @_elt.add @_points_display.elt()
    @_elt.add @_tichu_status

  update: ->
    @_user_info.set_text (@gc.username_for_player @player_id)

    player = @gc.state().players[@player_id]
    tichu_text = switch player.tichu_level
      when logic.GRAND then 'Grand Tichu'
      when logic.TICHU then 'Tichu'
      else null
    @_tichu_status.set_text tichu_text
    @_points_display?.update()

  elt: -> @_elt


class TichuOpponentHands
  constructor: (@gc, @player_id, opts) ->
    @_opp_info = []
    info_elts = {}
    for pos, idx in ['left', 'top', 'right']
      other_id = (@player_id + idx + 1) % 4
      info = new PlayerInfo @gc, other_id, opts
      @_opp_info.push info
      info_elts[pos] = info.elt()

    get_hand_size = (player_id) =>
      @gc.state().players[player_id].cards.length
    @_opp_hands = new OpponentHands @player_id,
      TichuCardGraphics, get_hand_size, {info_elts}

  update: ->
    @_opp_hands.update()
    for info in @_opp_info
      info.update()

  attach: (root) ->
    @_opp_hands.attach_to_root root


class BottomDisplay
  DEFAULT_OPTS =
    ctrls: null

  constructor: (@gc, @player_id, opts) ->
    opts ?= DEFAULT_OPTS
    @_card_hand = new CardHand TichuCardGraphics, {
      peek_ratio: 0.3
      attrs: {orig_index: null}
    }
    @_ctrls = opts.ctrls
    @_elt = new HBox {spacing: 20}, [@_card_hand]
    @_elt.add @_ctrls if @_ctrls?

  update_hand: (hand) ->
    CardArranger.update_hand @_card_hand, hand, (a, b) =>
      return (tichu_helpers_m.hash_card a) == (tichu_helpers_m.hash_card b)

  elt: -> @_elt

  card_hand: -> @_card_hand


class SharedUI
  DEFAULT_OPTS =
    ctrls: null
    display_pts: false

  constructor: (@gc, @player_id, @root) ->
    @_active = false
    @_hand_info = null
    @_opp_hands = @_bottom_disp = @_card_hand = null

  card_hand: -> @_card_hand

  update: ->
    assert @_active
    player = @gc.state().players[@player_id]

    @_bottom_disp.update_hand player.cards
    @_opp_hands.update()

  init: (opts) ->
    opts ?= DEFAULT_OPTS
    @_active = true
    player = @gc.state().players[@player_id]

    @_bottom_disp = new BottomDisplay @gc, @player_id, {
      ctrls: opts.ctrls
    }
    @_opp_hands = new TichuOpponentHands @gc, @player_id, {
      points_display: opts.display_pts
    }

    @_card_hand = @_bottom_disp.card_hand()
    if @_hand_info?
      @_card_hand.set_hand_from_info @_hand_info
    else
      @_bottom_disp.update_hand player.cards

    @_opp_hands.attach @root
    @root.set_child 'bottom', @_bottom_disp.elt()
    # TODO: should we always @update() here?

  cleanup: ->
    for pos in ['left', 'right', 'top', 'bottom', 'center']
      @root.set_child pos, null
    @_hand_info = @_card_hand.get_hand_info()
    @_active = false


#exports.PlayerInfo = PlayerInfo
#exports.TichuOpponentHands = TichuOpponentHands
exports.PhoenixPicker = PhoenixPicker
exports.WishPicker = WishPicker
exports.SharedUI = SharedUI
