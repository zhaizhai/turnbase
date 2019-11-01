assert = require 'assert'
util_m = require 'shared/util.iced'

{MixinClass} = require 'canvas/mixin.iced'
{CanvElement, ChildList, MouseAdapter, ChildRender, ChildMap} = require 'canvas/adapter.iced'

canvas_util_m = require 'canvas/canvas_util.iced'
{space_rectangle} = require 'canvas/layout_util.iced'

NBorderFrame = MixinClass 'NBorderFrame', [
  CanvElement, ChildMap, ChildRender, MouseAdapter
],
  # positions are [0...@n] and 'center'
  constructor: (@n, opts) ->
    if typeof @n isnt 'number' or @n <= 1
      throw new Error "Invalid n #{@n}"
    {@width, @height, @margin} = opts
    if not @width? or not @height? or not @margin?
      throw new Error "Invalid opts!"

  layout: ->
    [w, h] = [@width - 2 * @margin, @height - 2 * @margin]

    center = @get_child 'center'
    if center?
      center.x = (@width - center.elt.width) / 2
      center.y = (@height - center.elt.height) / 2

    positions = space_rectangle w, h, @n
    for {x, y}, idx in positions
      child = @get_child idx
      if child?
        child.x = @margin + x - (child.elt.width / 2)
        child.y = @margin + y - (child.elt.height / 2)

    @set_dirty true
    @parent.layout() if @parent?

  render: (ctx) ->
    @render_children ctx

# Element for displaying a "trick" consisting of n cards.
# TODO: maybe this should go under /cards
NTrick = MixinClass 'NTrick', [CanvElement],
  constructor: (@cards, @card_graphics, opts) ->
    {@width, @height} = opts
    if not @width? or not @height?
      throw new Error "Must provide width and height!"
    @highlighted_idx = null

  set_highlighted_idx: (@highlighted_idx) ->
    @set_dirty true

  layout: ->
    @set_dirty true
    @parent.layout() if @parent?

  render: (ctx) ->
    cw = @card_graphics.CARD_WIDTH
    ch = @card_graphics.CARD_HEIGHT

    positions = space_rectangle (@width - cw),
      (@height - ch), @cards.length
    for card, idx in @cards
      {x, y} = positions[idx]
      # TODO: allow customization of card size
      if card?
        @card_graphics.draw_card ctx, card, x, y
      else if idx is @highlighted_idx
        r = 4
        ctx.strokeStyle = 'red'
        canvas_util_m.strokeRoundRect ctx, x, y,
          @card_graphics.CARD_WIDTH, @card_graphics.CARD_HEIGHT, r

exports.NBorderFrame = NBorderFrame
exports.NTrick = NTrick