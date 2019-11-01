assert = require 'assert'
Client = require 'game_engine/client/setup.iced'
util_m = require 'shared/util.iced'
{T} = require 'shared/T/T.iced'
{R} = require 'client/lib/R.iced'

# modal_m = require 'client/lib/modal.iced'
{TextBox, InvisibleBox, Button} = require 'canvas/window.iced'
{BorderFrame, Frame, HBox, VBox} = require 'canvas/container.iced'
{CardHand, HiddenCardHand, CardArranger, CardSelector} = require 'canvas/cards/card_hand.iced'
{ClassicCards} = require 'canvas/cards/card_graphics.iced'
ClassicCardGraphics = ClassicCards.get_graphics()

{NBorderFrame, NTrick} = require 'canvas/n_player.iced'

class UIHelpers
  constructor: (@gc, @player_id) ->

  player_offset: (player_id) ->
    num_players = @gc.num_players()
    return (player_id + num_players - @player_id) % num_players

  tricks_str: (player_id) ->
    player = @gc.state().players[player_id]
    if not player.bid? then return "[no bid]"
    return "[tricks: #{player.tricks_taken}/#{player.bid}]"

  player_info: (player_id) ->
    return new TextBox {
      text: "#{@gc.username_for_player player_id} #{@tricks_str player_id}"
      size: 10, style: 'bold'
    }

  make_opp_hand: (player_id) ->
    player = gc.state().players[player_id]
    return new VBox {}, [
      (@player_info player_id)
      new HiddenCardHand ClassicCardGraphics, {
        n: player.cards.length, peek_ratio: 0.1
      }
    ]

  make_hands: ->
    return new NBorderFrame @gc.num_players(), {
      margin: 80, width: 800, height: 600
    }

  make_trick_display: (cards, player_to_play) ->
    trick = (null for _ in [0...@gc.num_players()])
    to_play_offset = (@player_offset player_to_play)
    for card, idx in cards
      card_offset = to_play_offset + @gc.num_players() - cards.length + idx
      card_offset %= @gc.num_players()
      trick[card_offset] = card
    ntrick = new NTrick trick,
      ClassicCardGraphics, { width: 400, height: 280}
    ntrick.set_highlighted_idx to_play_offset
    return ntrick

class BidHandler
  constructor: (@gc, @player_id, @root) ->
    @_ui_helpers = new UIHelpers @gc, @player_id

  _make_bid_buttons: ->
    buttons = []
    max_bid = @gc.state().num_rounds - @gc.state().total_bid_so_far
    for bid in [0..max_bid]
      do (bid) =>
        buttons.push (new Button {
          text: "#{bid}"
          handler: =>
            @gc.submit_action 'bid', [bid]
        })
    return new HBox {}, buttons

  update: ->
    hands = @_ui_helpers.make_hands()
    hands.set_child 'center', (@_ui_helpers.make_trick_display [], @gc.state().cur_turn)

    for player, idx in @gc.state().players
      if idx is @player_id
        my_hand = [
          (@_ui_helpers.player_info @player_id)
          new CardHand ClassicCardGraphics, { hand: player.cards.slice() }
        ]
        if @gc.state().cur_turn is @player_id
          my_hand.push @_make_bid_buttons()
        hands.set_child 0, (new VBox {}, my_hand)
      else
        hands.set_child (@_ui_helpers.player_offset idx),
          (@_ui_helpers.make_opp_hand idx)

    @root.set_child 'center', hands

  init: ->
    @update()
  action: ->
    @update()
  cleanup: -> # TODO

class PlayRoundHandler
  constructor: (@gc, @player_id, @root) ->
    @_ui_helpers = new UIHelpers @gc, @player_id

  _make_own_hand: ->
    my_hand = new CardHand ClassicCardGraphics, {
      hand: @gc.state().players[@player_id].cards.slice()
    }
    selector = new CardSelector my_hand
    selector.activate()
    play_button = new Button {
      text: 'Play'
      handler: =>
        sel = selector.get_selection()
        if not sel? then return
        @gc.submit_action 'play', [sel.idx]
    }
    controls = new VBox {}, [
      (@_ui_helpers.player_info @player_id)
      play_button
    ]
    return new HBox {}, [my_hand, controls]

  update: ->
    hands = @_ui_helpers.make_hands()
    hands.set_child 'center',
      (@_ui_helpers.make_trick_display @gc.state().cur_trick, @gc.state().cur_turn)
    for player, idx in @gc.state().players
      if idx is @player_id
        hands.set_child 0, @_make_own_hand()
      else
        hands.set_child (@_ui_helpers.player_offset idx),
          (@_ui_helpers.make_opp_hand idx)
    @root.set_child 'center', hands

  init: ->
    @update()
  action: (data, cb) ->
    @update()
    if @gc.state().cur_trick.length is @gc.num_players()
      # Pause to view last play of trick.
      await setTimeout defer(), 1000
    return cb()
  cleanup: -> # TODO

Client.setup {
  resources: [ClassicCards.get_resource()]
  background: '#008000'
  dims: {width: 820, height: 620}
  # TODO: infer this automatically
  game_spec: window.ALL_GAMES.ohhell

  make_mode_handlers: (canv_root, gc, player_id) ->
    root = new BorderFrame {
      forced_dims: {width: 800, height: 600}
      background: '#008000'
    }
    canv_root.add root, 10, 10
    return {
      Bid: (new BidHandler gc, player_id, root)
      PlayRound: (new PlayRoundHandler gc, player_id, root)
    }
}
