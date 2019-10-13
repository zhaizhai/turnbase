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

make_ladders = (gc) ->
  ladder_elts = []
  for ladder, idx in gc.state().ladders
    if ladder.length is 0
      ladder_elts.push (new HiddenCardHand ClassicCardGraphics, {
        n: 1
      })
      continue
    suit = 'CDHS'[idx]
    ladder_cards = []
    for value in ladder
      if value is -1
        # joker
        ladder_cards.push { suit, value: 1 }
      else
        ladder_cards.push { suit, value }
    ladder_elts.push (new CardHand ClassicCardGraphics, {
      peek_ratio: 0.3, hand: ladder_cards
    })
  return new VBox {}, ladder_elts

make_hands = (gc) ->
  cur_player_id = gc.state().cur_turn
  hands = []
  for player, player_id in gc.state().players
    hand_elts = [
      new TextBox {
        text: (gc.username_for_player player_id), width: 100
        size: (if player_id is gc.state().cur_turn then 18 else 15)
        style: (if player_id is gc.state().cur_turn then 'bold' else '')
      }
    ]
    for card, idx in player.cards
      do (idx) =>
        possible_suits = player.knowledge[idx].possible_suits.join('')
        known_min = player.knowledge[idx].known_min_value
        known_max = player.knowledge[idx].known_max_value
        known_range = "[#{known_min},#{known_max}]"

        hand_elt = if T.is_masked card
          if player_id is cur_player_id
            under_card = new Button {
              text: "#{known_range}\n#{possible_suits}", size: 10
              handler: => gc.submit_action 'play', [idx]
            }
          else
            under_card = new TextBox { text: "#{known_range}\n#{possible_suits}", size: 10 }
          new VBox {}, [
            # TODO: render this differently
            new HiddenCardHand ClassicCardGraphics, { n: 1 }
            under_card
          ]
        else
          new VBox {}, [
            new CardHand ClassicCardGraphics, { hand: [card] }
            new TextBox { text: "#{known_range}\n#{possible_suits}", size: 10 }
          ]
        hand_elts.push hand_elt
    hands.push (new HBox {}, hand_elts)
  return new VBox {}, hands

class SelectOne
  constructor: (items) ->
    @_sel = null
    @_buttons = {}

    button_list = []
    for [item_name, item_value] in items
      assert not @_buttons[item_value]?
      @_buttons[item_value] = @_make_select_button item_name, item_value
      button_list.push @_buttons[item_value]
    @_elt = new HBox {}, button_list

  _make_select_button: (item_name, item_value) ->
    return new Button {
      text: "#{item_name}", width: 50, height: 30
      handler: =>
        if @_sel?
          @_buttons[@_sel].enable()
        @_sel = item_value
        @_buttons[@_sel].disable()
    }

  selection: -> @_sel
  elt: -> @_elt

class PlayOrPassHandler
  constructor: (@gc, @player_id, @root) ->

  _make_play_component: ->
    elements = [
      make_hands @gc
    ]
    if @player_id is gc.state().cur_turn
      elements.push new Button {
        text: "Done playing", width: 50, height: 30
        handler: => gc.submit_action 'pass', []
      }
    else
      elements.push new TextBox {
        text: "#{gc.username_for_player gc.state().cur_turn} is playing", width: 50, height: 30
      }
    return new VBox {}, elements

  update: ->
    @root.set_child 'center', (new HBox {}, [
      @_make_play_component()
      (make_ladders @gc)
    ])

    status_mesg = "Cards in deck: #{@gc.state().deck.length}, Dings: #{@gc.state().dings}"
    @root.set_child 'bottom', (new TextBox {
        text: status_mesg
    })

  init: ->
    @update()

  action: ->
    @update()

  cleanup: -> # TODO


class HintOrPassHandler
  constructor: (@gc, @player_id, @root) ->

  _make_hint_button: (hands_list_display, hint_type, hint_value) ->
    if hint_type is 'hint_value'
      hint_text = "|"
    else
      hint_text = "#{hint_value}"
    return new Button {
      text: "#{hint_text}", width: 30, height: 30
      handler: =>
        if not @_select_one.selection()? then return
        @gc.submit_action hint_type, [@_select_one.selection(), hint_value]
    }

  _make_hint_component: ->
    hands = make_hands @gc
    elements =  [
      hands
    ]

    if @player_id is gc.state().cur_turn
      hint_suit_buttons = []
      for suit in 'CDHS'
        hint_suit_buttons.push (@_make_hint_button hands, 'hint_suit', suit)

      hint_value_buttons = []
      for value in [2..@gc.state().cards_per_suit]
        hint_value_buttons.push new TextBox { text: "#{value}", size: 10 }
        hint_value_buttons.push (@_make_hint_button hands, 'hint_value', value)
      hint_value_buttons.push new TextBox { text: "#{@gc.state().cards_per_suit + 1}", size: 10 }
      elements.push @_select_one.elt()
      elements.push new HBox {}, hint_suit_buttons
      elements.push new HBox {}, hint_value_buttons
      elements.push new Button {
        text: "No hint", width: 50, height: 30
        handler: => gc.submit_action 'pass', []
      }
    else
      elements.push new TextBox {
        text: "#{gc.username_for_player gc.state().cur_turn} is hinting", width: 50, height: 30
      }

    return new VBox {}, elements

  update: ->
    @root.set_child 'center', (new HBox {}, [
      @_make_hint_component()
      (make_ladders @gc)
    ])

    status_mesg = "Cards in deck: #{@gc.state().deck.length}, Dings: #{@gc.state().dings}"
    @root.set_child 'bottom', (new TextBox {
        text: status_mesg
    })

  init: ->
    @_select_one = new SelectOne (
      ([(@gc.username_for_player i), i] for i in [0...@gc.state().players.length] when (i isnt @player_id))
    )
    @update()

  action: ->
    @update()

  cleanup: -> # TODO

class PlayOrDiscardHandler
  constructor: (@gc, @player_id, @root) ->

  _make_play_or_discard_choices: ->
    card = @gc.state().card
    elements = [
      new TextBox { text: "#{card.value}:#{card.suit}" }
    ]
    if @player_id is gc.state().cur_turn
      elements.push new Button {
        text: 'Play'
        handler: => @gc.submit_action 'play', []
      }
      elements.push new Button {
        text: 'Discard'
        handler: => @gc.submit_action 'discard', []
      }
    return new VBox {}, elements

  update: ->
    @root.set_child 'center', (new HBox {}, [
      @_make_play_or_discard_choices()
      (make_ladders @gc)
    ])

  init: ->
    @update()

  action: ->
    @update()

  cleanup: -> # TODO


Client.setup {
  resources: [ClassicCards.get_resource()] # TODO
  background: '#008000'
  dims: {width: 820, height: 620}
  # TODO: infer this automatically
  game_spec: window.ALL_GAMES.ladderfall

  make_mode_handlers: (canv_root, gc, player_id) ->
    root = new BorderFrame {
      forced_dims: {width: 800, height: 600}
      background: '#008000'
    }
    canv_root.add root, 10, 10
    return {
      HintOrPass: (new HintOrPassHandler gc, player_id, root)
      PlayOrPass: (new PlayOrPassHandler gc, player_id, root)
      PlayOrDiscard: (new PlayOrDiscardHandler gc, player_id, root)
    }
}
