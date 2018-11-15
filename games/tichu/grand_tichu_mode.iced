window_m = require 'canvas/window.iced'
{Button, TextInfo} = window_m
container_m = require 'canvas/container.iced'
{BorderFrame, HBox, VBox} = container_m

modal_m = require 'client/lib/modal.iced'
{CardArranger} = require 'canvas/cards/card_hand.iced'

class GrandTichuController
  constructor: (@gc, @player_id, @root, @shared) ->
    grand_button = new Button {
      text: 'Grand Tichu!'
      width: 120
      handler: =>
        await @gc.submit_action 'grand', [], defer err, res
        throw err if err
    }
    next_cards_button = new Button {
      text: 'Next Cards'
      width: 120
      handler: =>
        await @gc.submit_action 'next_cards', [], defer err, res
        throw err if err
    }
    @_ctrls = new VBox {spacing: 10}, [grand_button, next_cards_button]
    @_arranger = null

  update: ->
    @shared.ui.update()
    player = @gc.state().players[@player_id]

    show_buttons = (player.cards.length isnt 14)
    for i in [0...2]
      @_ctrls.set_visible i, show_buttons

  init: ->
    @shared.scoreboard.update_score()
    @shared.ui.init {ctrls: @_ctrls}
    @_arranger = new CardArranger @shared.ui.card_hand(), {}
    @_arranger.activate()
    @update()

  cleanup: ->
    @shared.ui.cleanup()

  action: (data, cb) ->
    @update()

    if data.action is 'grand'
      await modal_m.flash {
        mesg: "#{data.username} calls Grand Tichu!"
        duration: 1000
      }, defer()
    return cb()

exports.GrandTichuController = GrandTichuController
