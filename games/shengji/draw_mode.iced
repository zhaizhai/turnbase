util_m = require 'shared/util.iced'

{Button} = require 'canvas/window.iced'
{HBox, VBox, Frame} = require 'canvas/container.iced'

{CardGraphics} = require 'canvas/card_graphics.iced'
{CardHand} = require 'canvas/card_hand.iced'

{make_opp_hands, PlayerInfo} = require 'games/shengji/shared_ui.iced'


class CardSelector
  constructor: (@card_hand) ->
    @_selected = null

  activate: ->
    @card_hand.click (idx) =>
      if @_selected? and @_selected is idx
        @card_hand.set_attr idx, 'raised', false
        @_selected = null
        return

      @_selected = idx
      for i in [0...@card_hand.num_cards()]
        @card_hand.set_attr i, 'raised', (i is idx)

  deactivate: ->
    @_selected = null
    @card_hand.set_all 'raised', false
    @card_hand.click null

  selection: -> @_selected


class DrawController
  constructor: (@gc, @player_id, @shared) ->
    @card_hand = new CardHand CardGraphics
    @cs = new CardSelector @card_hand
    @_opp_hands = make_opp_hands @gc, @player_id
    @_own_info = new PlayerInfo @gc, @player_id

    @_declare_button = new Button {
      text: 'Declare'
      handler: =>
        sel = @cs.selection()
        return if not sel?

        await gc.submit_action {
          cmd: 'declare', info: [sel]
        }, defer err, res
        throw err if err
    }
    @_declared = new CardHand CardGraphics

  update: ->
    @shared.scoreboard.update()
    @_opp_hands.update()
    @_own_info.update()
    me = @gc.state().players[@player_id]
    # TODO: need to save info
    @card_hand.set_hand me.cards

  init: ->
    @cs.activate()
    @_opp_hands.elt.attach_to_root @shared.root
    @shared.root.set_child 'center', @_declared

    @update()
    spacer = new Frame {
      height: @card_hand.height
      width: 240
    }
    spacer.add @card_hand, 0, 0
    @shared.root.set_child 'bottom', new HBox {spacing: 20},
      [spacer, @_declare_button, @_own_info.elt()]

    @consider_draw()

  action: (data) ->
    console.log 'got action!', data
    if @gc.game().declared?
      @_declared.set_hand [{
        suit: @gc.game().declared
        value: @gc.state().trump_value
      }]

    @_opp_hands.update()
    me = @gc.state().players[@player_id]

    if data.cmd is 'draw' and data.player_id is @player_id
      drawn = util_m.last me.cards
      @card_hand.insert @card_hand.num_cards(), drawn

    @consider_draw()

  cleanup: ->
    for pos in ['left', 'right', 'top', 'bottom', 'center']
      @shared.root.set_child pos, null

  consider_draw: ->
    if @gc.game().cur_player is @player_id
      await setTimeout defer(), 500
      await gc.submit_action {cmd: 'draw', info: []}, defer err, res
      console.log "returned from player #{@player_id} draw", err, res

exports.DrawController = DrawController
