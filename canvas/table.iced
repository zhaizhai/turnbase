assert = require 'assert'
util_m = require 'shared/util.iced'

{MixinClass} = require 'canvas/mixin.iced'
{CanvElement, ChildList, MouseAdapter, ChildRender, ChildMap} = require 'canvas/adapter.iced'

Table = MixinClass 'Table', [
  CanvElement, MouseAdapter, ChildRender, ChildList
],
  constructor: (@rows, @columns, opts = {}) ->
    @padding = opts.padding ? 8
    @_dummy_child =
      x: 0, y: 0, visible: false
      elt:
        render: ->
        set_dirty: ->
    @children = (@_dummy_child for _ in [0...(@rows * @columns)])
    @layout()

  _in_bounds: (r, c) ->
    return (0 <= r < @rows) and (0 <= c < @columns)

  get_cell: (r, c) ->
    if not (@_in_bounds r, c) then return null
    child = @children[r * @columns + c]
    if child is @_dummy_child
      return null
    return child.elt

  set_cell: (r, c, elt) ->
    assert @_in_bounds r, c
    @children[r * @columns + c] =
      elt: elt, x: 0, y: 0, visible: true
    elt.parent = @
    @layout()

  set_row: (r, elts) ->
    assert (0 <= r < @rows) and (elts.length <= @columns)
    for elt, c in elts
      @children[r * @columns + c] =
        elt: elt, x: 0, y: 0, visible: true
      elt.parent = @
    @layout()

  layout: ->
    @height = @padding
    for r in [0...@rows]
      max_h = 0
      for c in [0...@columns]
        cell = @get_cell r, c
        if not cell? then continue
        max_h = Math.max max_h, cell.height
      for c in [0...@columns]
        child = @children[r * @columns + c]
        if child isnt @_dummy_child
          child.y = @height + (max_h/2) - (child.elt.height/2)
      @height += max_h + @padding

    @width = @padding
    for c in [0...@columns]
      max_w = 0
      for r in [0...@rows]
        cell = @get_cell r, c
        if not cell? then continue
        max_w = Math.max max_w, cell.width
      for r in [0...@rows]
        child = @children[r * @columns + c]
        if child isnt @_dummy_child
          child.x = @width + (max_w/2) - (child.elt.width/2)
      @width += max_w + @padding

    @set_dirty true
    if @parent? then @parent.layout()

  render: (ctx) ->
    @render_children ctx

exports.Table = Table