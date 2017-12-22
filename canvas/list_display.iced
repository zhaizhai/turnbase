assert = require 'assert'
canvas_util_m = require 'canvas/canvas_util.iced'
util_m = require 'shared/util.iced'
{MixinClass} = require 'canvas/mixin.iced'
{CanvElement} = require 'canvas/adapter.iced'

ListDisplay = MixinClass 'ListDisplay', [
  CanvElement
],
  constructor: (@list, opts) ->
    REQUIRED = ['item_width', 'item_height', 'draw']
    for k in REQUIRED
      assert opts[k]?
      @[k] = opts[k]
    @_sel = null
    @_on_change = =>
    @layout()

  selection: ->
    if not @_sel? then return {index: null, item: null}
    return { index: @_sel, item: @list[@_sel] }
  on_change: (@_on_change) ->

  layout: ->
    @width = @item_width
    @height = @item_height * @list.length
    @parent?.layout()
    @set_dirty true

  mouse_evt: (evt, x, y) ->
    if evt is 'click'
      new_sel = Math.floor (y / @item_height)
      new_sel = util_m.clamp new_sel, 0, (@list.length - 1)
      if new_sel is @_sel
        @_sel = null
      else
        @_sel = new_sel
      @_on_change()
      @set_dirty true

  render: (ctx) ->
    ctx.save()
    for item, idx in @list
      @draw ctx, item
      if @_sel is idx
        ctx.strokeStyle = "black"
        ctx.strokeWidth = 3
        canvas_util_m.strokeRoundRect ctx, 2, 2,
          (@item_width - 4), (@item_height - 4), 4
      ctx.translate 0, @item_height
    ctx.restore()

exports.ListDisplay = ListDisplay