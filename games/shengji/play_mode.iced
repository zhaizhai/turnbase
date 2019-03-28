{Timer} = require 'shared/timer.iced'

{TurnIndicator} = require 'canvas/four_player.iced'
{CardGraphics} = require 'canvas/card_graphics.iced'
{CardHand, HiddenCardHand} = require 'canvas/card_hand.iced'

{MixinClass} = require 'canvas/mixin.iced'
{CanvElement, ChildList, ChildRender} = require 'canvas/adapter.iced'

{Button, TextInfo} = require 'canvas/window.iced'
{HBox, VBox, OverlayContainer} = require 'canvas/container.iced'

{make_opp_hands, PlayerInfo} = require 'games/shengji/shared_ui.iced'

POSITIONS = [
  [0, 1] # bottom
  [-1, 0] # left
  [0, -1] # top
  [1, 0] # right
]
TrickDisplay = MixinClass 'TrickDisplay', [
  CanvElement, ChildList, ChildRender
],
  constructor: (@gc, @player_id, opts) ->
    {@width, @height} = opts
    for i in [0...4]
      ch = new CardHand CardGraphics, {peek_ratio: 0.3}
      @add_child ch, 0, 0
    @layout()
    @_hidden = false

  hide: ->
    @_hidden = true
    @set_dirty true
  show: ->
    @_hidden = false
    @set_dirty true

  layout: ->
    for info, idx in @children
      # TODO: incorporate scaling
      scaling = 1.0
      [x, y] = POSITIONS[idx]
      [x, y] = [x * @width / 4, y * @height / 4]
      [x, y] = [x + (@width / 2), y + (@height / 2)]
      [x, y] = [x - scaling * (info.elt.width / 2),
                y - scaling * (info.elt.height / 2)]
      info.x = x
      info.y = y
    @parent?.layout()

  update: ->
    trick = @gc.game().cur_trick
    cards = if trick? then trick.cards.slice() else []
    lead = if trick? then trick.lead else @gc.game().cur_turn

    while cards.length < 4
      cards.push null
    for play, idx in cards
      offset = (lead + idx - @player_id + 4) % 4
      @children[offset].elt.set_hand (play ? [])
    @layout()

  render: (ctx) ->
    return if @_hidden
    @render_children ctx


class TrickAnimation
  constructor: (@overlay, @trick_display,
                @target, @duration) ->
    @_timer = new Timer

  run: (cb) ->
    @overlay.set_draw_over (@draw.bind @)
    @overlay.set_dirty true
    @_timer.start @duration, =>
      @done()
      cb()
    @trick_display.hide()

  draw: (ctx) ->
    [x, y] = @trick_display.get_offset @overlay
    [tx, ty] = @target
    elapsed_ratio = @_timer.elapsed_ratio()
    interp = (a, b, lambda) ->
      return lambda * a + (1 - lambda) * b

    for info in @trick_display.children
      draw_x = interp (tx - info.elt.width / 2),
        (x + info.x), elapsed_ratio
      draw_y = interp (ty - info.elt.height / 2),
        (y + info.y), elapsed_ratio

      ctx.translate draw_x, draw_y
      info.elt.render ctx
      ctx.translate -draw_x, -draw_y

    await setTimeout defer(), 0
    @overlay.set_dirty true

  done: ->
    @trick_display.update()
    # TODO: at this point trick hasn't cleared yet!
    @trick_display.show()
    @overlay.set_draw_over null


class PlayController
  constructor: (@gc, @player_id, @shared) ->
    @_opp_hands = make_opp_hands @gc, @player_id
    @_own_info = new PlayerInfo @gc, @player_id

    @_card_hand = new CardHand CardGraphics
    @_card_hand.click (idx) =>
      info = @_card_hand.get_info idx
      @_card_hand.set_attr idx, 'raised', (not info.raised)

    @_play_button = new Button {
      text: 'Play'
      handler: =>
        selected = @_card_hand.filter (info) ->
          return info.raised
        idxs = (info.idx for info in selected)
        await gc.submit_action {
          cmd: 'play', info: [idxs]
        }, defer err, res
        throw err if err
    }

    w = CardGraphics.CARD_WIDTH * 6
    h = CardGraphics.CARD_HEIGHT * 4
    @_td = new TrickDisplay @gc, @player_id, {
      width: 0.8 * w, height: 0.8 * h
    }
    @_center_elt = new TurnIndicator {
      width: w, height: h, center: @_td
    }
    @_center_overlay = new OverlayContainer @_center_elt

  update: ->
    @_opp_hands.update()
    @_own_info.update()

    me = @gc.state().players[@player_id]
    @_card_hand.set_hand me.cards
    @_td.update()

    offset = (@gc.game().cur_turn - @player_id + 4) % 4
    directions = ['bottom', 'left', 'top', 'right']
    @_center_elt.set_primary directions[offset]

  init: ->
    @shared.scoreboard.update()
    @_opp_hands.elt.attach_to_root @shared.root
    @shared.root.set_child 'center', @_center_overlay
    @shared.root.set_child 'bottom', new HBox {spacing: 20},
      [@_card_hand, @_play_button, @_own_info.elt()]
    @update()

  action: (data, cb) ->
    @update()
    cur_trick = @gc.game().cur_trick
    if not cur_trick? or cur_trick.cards.length isnt 4
      return cb()
    # trick over

    offset = (@gc.game().cur_turn - @player_id + 4) % 4
    [w, h] = [@_center_overlay.width, @_center_overlay.height]
    info = @_td.children[offset]

    # animation target
    [x, y] = info.elt.get_offset @_center_overlay
    [x, y] = [x + (info.elt.width / 2),
              y + (info.elt.height / 2)]

    ta = new TrickAnimation @_center_overlay, @_td,
      [x, y], 300 # TODO: set target properly

    await setTimeout defer(), 200 # short pause
    await ta.run defer()
    return cb()

  cleanup: ->
    for pos in ['left', 'right', 'top', 'bottom', 'center']
      @shared.root.set_child pos, null


exports.PlayController = PlayController
