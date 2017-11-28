assert = require 'assert'
container_m = require 'canvas/container.iced'
{BorderFrame, HBox, VBox} = container_m
{HiddenCardHand} = require 'canvas/cards/card_hand.iced'

{MixinClass} = require 'canvas/mixin.iced'
{CanvElement, ChildMap, ChildRender, MouseAdapter} = require 'canvas/adapter.iced'

class OpponentHands
  DEFAULT_OPTS =
    vert_peek: 0.1
    horiz_peek: 0.3
    info_elts:
      left: null
      top: null
      right: null

  # get_hand_size = (player_id) -> num cards
  constructor: (@player_id, @cg, @get_hand_size, opts) ->
    opts ?= {}
    for k, v of DEFAULT_OPTS
      opts[k] ?= v

    # contains the other players' hidden card hands
    @opp_info = []

    other_hand_info = [
      ['left', 'VERT', opts.vert_peek]
      ['top', 'HORIZ', opts.horiz_peek]
      ['right', 'VERT', opts.vert_peek]
    ]

    for info, idx in other_hand_info
      [pos, orient, peek_ratio] = info

      hidden_hand = new HiddenCardHand @cg, {
        peek_ratio: peek_ratio, n: 0, orientation: orient
      }

      info_elt = opts.info_elts[pos]
      elts = if info_elt?
        [info_elt, hidden_hand]
      else
        [hidden_hand]
      container = if pos is 'left'
        # elts.reverse()
        new VBox {spacing: 4}, elts
      else if pos is 'top'
        new HBox {spacing: 4}, elts
      else
        new VBox {spacing: 4}, elts

      @opp_info.push {
        pos: pos
        hand: hidden_hand
        info_elt: info_elt
        container: container
      }

  get_info_elt: (player_id) ->
    offset = (player_id - @player_id + 4) % 4
    assert offset in [1, 2, 3], "invalid player_id #{player_id}"
    return @opp_info[offset - 1].info_elt

  update: ->
    for i in [0...3]
      cur_player = (@player_id + i + 1) % 4
      n = @get_hand_size cur_player
      @opp_info[i].hand.set_num_cards n

  attach_to_root: (root) ->
    # root has to be a BorderFrame
    for info in @opp_info
      root.set_child info.pos, info.container


ARROW_WIDTH = 40
ARROW_LENGTH = 40
TurnIndicator = MixinClass 'TurnIndicator', [
  CanvElement, ChildMap, ChildRender, MouseAdapter
],
  constructor: (opts) ->
    {@width, @height, center} = opts
    # TODO: make dims account for @center?
    @_dir = @_second_dir = null
    @set_child 'center', center
    center_info = @get_child 'center'
    center_info.x = (@width - center.width) / 2
    center_info.y = (@height - center.height) / 2

  set_primary: (@_dir) ->

  set_secondary: (@_second_dir) ->

  layout: ->
    # TODO: account for changing center here
    @parent.layout() if @parent?

  render: (ctx) ->
    if @_dir?
      [_, x, y] = @_draw_info()[@_dir]
      @_draw_arrow ctx, @_dir, x, y, 'black'
    if @_second_dir?
      [_, x, y] = @_draw_info()[@_second_dir]
      @_draw_arrow ctx, @_second_dir, x, y, 'yellow'
    @render_children ctx

  _draw_info: ->
    info = # [angle, x, y]
      left: [90, 0, (@height / 2)]
      right: [270, @width, (@height / 2)]
      top: [180, (@width / 2), 0]
      bottom: [0, (@width / 2), @height]
    return info

  _draw_arrow: (ctx, dir, x, y, color = 'black') ->
    ctx.save()

    ctx.translate x, y
    angle = @_draw_info()[dir][0]
    ctx.rotate (angle * Math.PI / 180)

    [w, l] = [ARROW_WIDTH / 4, ARROW_LENGTH / 4]
    ctx.fillStyle = color
    ctx.fillRect -w, -(2 * w), (2 * w), w

    ctx.beginPath()
    ctx.moveTo (-2 * w), -w
    ctx.lineTo 0, 0
    ctx.lineTo (2 * w), -w
    ctx.fill()

    ctx.restore()


exports.OpponentHands = OpponentHands
exports.TurnIndicator = TurnIndicator
