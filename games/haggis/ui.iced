assert = require 'assert'
Client = require 'game_engine/client/setup.iced'
util_m = require 'shared/util.iced'
{T} = require 'shared/T/T.iced'
{R} = require 'client/lib/R.iced'

modal_m = require 'client/lib/modal.iced'
logic_m = require 'games/haggis/haggis_logic.iced'
{TextBox, InvisibleBox, Button} = require 'canvas/window.iced'
{BorderFrame, Frame, HBox, VBox} = require 'canvas/container.iced'
{CardHand, HiddenCardHand, CardArranger, CardSelector} = require 'canvas/cards/card_hand.iced'
{TurnIndicator} = require 'canvas/cards/four_player.iced'

{ClassicCards} = require 'canvas/cards/card_graphics.iced'
ClassicCardGraphics = ClassicCards.get_graphics (card) ->
  if card.suit in 'JQK'
    return [0, (9 + 'JQK'.indexOf card.suit)]
  return ['ABCD'.indexOf(card.suit), (card.value - 2)]

class PlayTrickHandler
  constructor: (@gc, @player_id, @root) ->
    @_my_hand = new CardHand ClassicCardGraphics, {
      # TODO: orig_index should be incorporated automatically
      peek_ratio: 0.3, attrs: {orig_index: null}
    }
    @_arranger = new CardArranger @_my_hand, {toggle_on_click: true}
    @_arranger.activate()

  _play: ->
    selection = @_arranger.get_selection()
    play_cards = (info.card for info in selection)
    play_idxs = (info.orig_index for info in selection)

    last_play = @gc.state().cur_trick.last_play()
    wild_val_choices = logic_m.valid_wild_values play_cards, last_play

    if wild_val_choices.length is 0
      return alert "Selected cards can't be played!"

    choice_idx = 0
    if wild_val_choices.length > 1
      await modal_m.choice {
        mesg: "Play as:"
        choices: wild_val_choices.map((x) -> x.display_string)
      }, defer choice_idx
      if not choice_idx? then return

    wild_values = wild_val_choices[choice_idx].values
    await @gc.submit_action 'play', [play_idxs, wild_values],
      defer err, res
    throw err if err

  _make_center: ->
    trick = @gc.state().cur_trick

    last_play = if trick.last_play()?
      new CardHand ClassicCardGraphics, {
        peek_ratio: 0.3, hand: trick.last_play()
      }
    else
      new InvisibleBox 10, 120
    spacer = new InvisibleBox 10, 120

    my_turn = @gc.state().cur_turn is @player_id
    center = new VBox {}, (if my_turn then [last_play, spacer] else [spacer, last_play])

    ret = new TurnIndicator {
      width: 400, height: 300, center: center
    }
    ret.set_primary (if my_turn then 'bottom' else 'top')
    return ret

  _points_display: (player_id) ->
    player = @gc.state().players[player_id]
    return new TextBox {
      size: 12, text: [
        "#{@gc.username_for_player player_id}"
        "Total pts: #{player.total_points}"
        "This round: #{player.round_points}"
      ].join('\n')
    }

  update: ->
    hand = @gc.state().players[@player_id].cards
    CardArranger.update_hand @_my_hand, hand, (a, b) =>
      return (a.suit + a.value) == (b.suit + b.value)

    action_buttons = new VBox {}, [
      new Button { text: 'Play', handler: (@_play.bind @) }
      new Button { text: 'Pass', handler: =>
          await @gc.submit_action 'pass', [], defer err, res
          throw err if err
      }
    ]

    opp = @gc.state().players[1 - @player_id]
    @root.set_child 'top', (new HBox {}, [
      new HiddenCardHand ClassicCardGraphics, {
        peek_ratio: 0.3, n: opp.cards.length
      }
      (@_points_display (1 - @player_id))
    ])
    @root.set_child 'center', @_make_center()
    @root.set_child 'bottom', (new HBox {}, [
      @_my_hand, action_buttons, (@_points_display @player_id)
    ])

  init: ->
    @update()

  action: ->
    @update()

  cleanup: -> # TODO


Client.setup {
  resources: [ClassicCards.get_resource()]
  background: '#008000'
  dims: {width: 620, height: 620}
  # TODO: infer this automatically
  game_spec: window.ALL_GAMES.haggis

  make_mode_handlers: (canv_root, gc, player_id) ->
    root = new BorderFrame {
      forced_dims: {width: 600, height: 600}
      background: '#008000'
    }
    canv_root.add root, 10, 10
    return {
      PlayTrick: (new PlayTrickHandler gc, player_id, root)
    }
}
