assert = require 'assert'
canvas_util_m = require 'canvas/canvas_util.iced'
{MixinClass} = require 'canvas/mixin.iced'
{CanvElement} = require 'canvas/adapter.iced'

class HoverLayer
  constructor: (@grid_disp, opts) ->
    @type = 'hover'
    {@rows, @cols} = opts
    @_draw = opts.draw

  offset: ->
    return [Math.floor((@rows - 1)/2), Math.floor((@cols - 1)/2)]

  draw: (ctx, r, c) ->
    [ro, co] = @offset()
    ctx.translate ((-co) * @grid_disp.size),
      ((-ro) * @grid_disp.size)
    @_draw ctx, (r - ro), (c - co)

class TileLayer
  constructor: (@grid_disp, opts) ->
    @type = 'tile'
    @_draw = opts.draw

  draw: (ctx) ->
    {rows, cols, size} = @grid_disp
    ctx.save()
    ctx.translate @grid_disp.margin, @grid_disp.margin
    for r in [0...rows]
      for c in [0...cols]
        @_draw ctx, r, c
        ctx.translate size, 0
      ctx.translate (-cols * size), size
    ctx.restore()

GridDisplay = MixinClass 'GridDisplay', [
  CanvElement
],
  constructor: (opts) ->
    REQUIRED = ['rows', 'cols', 'size']
    DEFAULTS =
      background: '#dddddd'

    for k in REQUIRED
      assert opts[k]?
      @[k] = opts[k]
    for k, v of DEFAULTS
      @[k] = opts[k] ? v
    @margin = opts.margin ? (0.5 * @size)

    @_hover_layer = null
    @_hover = null
    @_layers = []

    @_click = (r, c, right) =>
    @layout()

  on_click: (@_click) ->

  # TODO: unify interfaces
  add_custom_layer: ({draw}) ->
    @_layers.push {
      type: 'custom', draw: (ctx) =>
        ctx.translate @margin, @margin
        draw ctx
        ctx.translate -@margin, -@margin
    }
  add_tile_layer: ({draw}) ->
    @_layers.push (new TileLayer @, {draw})
  add_hover_layer: ->
    @_layers.push {type: 'hover'}

  set_hover_layer: (opts) ->
    if not opts?
      @_hover_layer = null
      return
    @_hover_layer = new HoverLayer @, opts
    @set_dirty true

  layout: ->
    @width = @size * @cols + 2 * @margin
    @height = @size * @rows + 2 * @margin
    @parent?.layout()
    @set_dirty true

  mouse_evt: (evt, x, y, extra) ->
    if evt is 'move'
      if @_is_within_current_hover x, y
        return
      @_hover = @mouse_to_grid_coords x, y
      @set_dirty true

    else if evt is 'leave'
      @_hover = null
      @set_dirty true

    else if evt is 'click'
      coords = @_hover ? (@mouse_to_grid_coords x, y)
      if coords?
        [r, c] = coords
        if @_hover_layer?
          [ro, co] = @_hover_layer.offset()
          [r, c] = [(r - ro), (c - co)]
        # TODO: check if in range??
        @_click r, c, extra.right

  _is_within_current_hover: (x, y) ->
    if not @_hover? then return false
    [r, c] = @_hover
    [hx, hy] = [@margin + c * @size, @margin + r * @size]
    buffer = 0.2 * @size
    if x < hx - buffer or x > hx + @size + buffer
      return false
    if y < hy - buffer or y > hy + @size + buffer
      return false
    return true

  mouse_to_grid_coords: (x, y) ->
    [r, c] = [(Math.floor ((y - @margin) / @size)),
              (Math.floor ((x - @margin) / @size))]
    if (r < 0 or r >= @rows or c < 0 or c >= @cols) then return null
    return [r, c]

  _render_grid_lines: (ctx) ->
    ctx.strokeStyle = 'black'
    ctx.beginPath()
    for r in [0..@rows]
      y = @margin + r * @size
      ctx.moveTo @margin, y
      ctx.lineTo (@width - @margin), y
    for c in [0..@cols]
      x = @margin + c * @size
      ctx.moveTo x, @margin
      ctx.lineTo x, (@height - @margin)
    ctx.stroke()

  _render_hover: (ctx) ->
    if (not @_hover?) or (not @_hover_layer?)
      return
    [r, c] = @_hover
    ctx.save()
    ctx.translate (@margin + c * @size), (@margin + r * @size)
    @_hover_layer.draw ctx, r, c
    ctx.restore()

  _render_layer: (ctx, layer) ->
    switch layer.type
      when 'hover' then @_render_hover ctx
      when 'custom' then layer.draw ctx
      when 'tile' then layer.draw ctx
      else throw new Error "Unrecognized layer type #{layer.type}"

  render: (ctx) ->
    # render background
    ctx.fillStyle = @background
    ctx.fillRect 0, 0, @width, @height

    ctx.save()
    ctx.beginPath()
    ctx.rect 0, 0, @width, @height
    ctx.clip()
    @_render_grid_lines ctx
    for layer in @_layers
      @_render_layer ctx, layer
    ctx.restore()

exports.GridDisplay = GridDisplay
