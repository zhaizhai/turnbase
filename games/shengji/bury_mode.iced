{Button} = require 'canvas/window.iced'
{HBox, VBox} = require 'canvas/container.iced'

{CardGraphics} = require 'canvas/card_graphics.iced'
{CardHand} = require 'canvas/card_hand.iced'

{make_opp_hands, PlayerInfo} = require 'games/shengji/shared_ui.iced'


class BuryController
  constructor: (@gc, @player_id, @shared) ->
    @card_hand = new CardHand CardGraphics
    @card_hand.click (idx) =>
      info = @card_hand.get_info idx
      @card_hand.set_attr idx, 'raised', (not info.raised)

    @_opp_hands = make_opp_hands @gc, @player_id
    @_own_info = new PlayerInfo @gc, @player_id

    @_bury_button = new Button {
      text: 'Bury'
      handler: =>
        selected = @card_hand.filter (info) ->
          return info.raised
        idxs = (info.idx for info in selected)
        await gc.submit_action {
          cmd: 'bury', info: [idxs]
        }, defer err, res
        throw err if err
    }
    @_declared = new CardHand CardGraphics

  init: ->
    @shared.scoreboard.update()
    @_opp_hands.elt.attach_to_root @shared.root
    @_opp_hands.update()
    @_own_info.update()

    me = @gc.state().players[@player_id]
    @card_hand.set_hand me.cards

    elts = [@card_hand]
    if @gc.state().master is @player_id
      elts.push @_bury_button
    elts.push @_own_info.elt()
    @shared.root.set_child 'bottom', new HBox {spacing: 20}, elts

    @_declared.set_hand [{
      suit: @gc.state().trump_suit
      value: @gc.state().trump_value
    }]
    @shared.root.set_child 'center', @_declared

  action: (data) ->

  cleanup: ->
    for pos in ['left', 'right', 'top', 'bottom', 'center']
      @shared.root.set_child pos, null

exports.BuryController = BuryController
