assert = require 'assert'
canvas_util_m = require 'canvas/canvas_util.iced'
{MixinClass} = require 'canvas/mixin.iced'
{CanvElement} = require 'canvas/adapter.iced'


# on_click (r, c) ->
# on_hover (r, c) ->
# draw_cell (ctx, {r, c, size, hover_r, hover_c}) ->
GridDisplay = MixinClass 'GridDisplay', [
  CanvElement
],
  constructor: (opts) ->
    REQUIRED = ['rows', 'cols', 'size']
    DEFAULTS =
      background: '#cccc66'
      draw_cell: (ctx, x, y, r, c) ->
      hover_width: 1
      hover_height: 1
      # hover_drawover: false
      draw_hover: (ctx, x, y, r, c) ->
      on_click: (r, c) ->
      on_hover: ->

      draw_over: (ctx) ->

    for k in REQUIRED
      assert opts[k]?
      @[k] = opts[k]
    for k, v of DEFAULTS
      @[k] = opts[k] ? v

    @margin = opts.margin ? (0.5 * @size)
    @_hover = null
    @layout()

  layout: ->
    @width = @size * @cols + 2 * @margin
    @height = @size * @rows + 2 * @margin
    @parent?.layout()
    @set_dirty true

  mouse_to_grid_coords: (x, y) ->
    [r, c] = [(Math.floor ((y - @margin) / @size)),
              (Math.floor ((x - @margin) / @size))]
    if (r < 0 or r >= @rows or c < 0 or c >= @cols) then return null
    return [r, c]

  block_mouse_to_grid_coords: (x, y) ->
    if not (@mouse_to_grid_coords x, y)?
      return null
    x_offset = 0.5 * (@hover_width - 1) * @size
    y_offset = 0.5 * (@hover_height - 1) * @size
    [gx, gy] = [x - @margin, y - @margin]
    gx = Math.min (@size * @cols - 0.001), (gx + x_offset)
    gx = Math.max 0, (gx - 2 * x_offset)
    gy = Math.min (@size * @rows - 0.001), (gy + y_offset)
    gy = Math.max 0, (gy - 2 * y_offset)

    ret = @mouse_to_grid_coords (gx + @margin), (gy + @margin)
    assert ret?
    return ret

  mouse_evt: (evt, x, y) ->
    if evt is 'move'
      @_hover = @block_mouse_to_grid_coords x, y
      if @_hover? then @on_hover()
      @set_dirty true

    else if evt is 'leave'
      @_hover = null
      @set_dirty true

    else if evt is 'click'
      coords = @block_mouse_to_grid_coords x, y
      if coords?
        [r, c] = coords
        @on_click r, c

  render: (ctx) ->
    # render background
    ctx.fillStyle = @background
    ctx.fillRect 0, 0, @width, @height

    # render each cell
    ctx.save()
    for r in [0...@rows]
      for c in [0...@cols]
        # TODO: respect hover_drawover
        # if @_hover? and @hover_drawover
        #   [hr, hc] = @_hover
        #   [hov_w, hov_h] = @hover_dims ? [1, 1]
        x = @margin + @size * c
        y = @margin + @size * r
        @draw_cell ctx, x, y, r, c
    ctx.restore()

    # render hover
    if @_hover?
      [hr, hc] = @_hover
      @draw_hover ctx, (@margin + @size * hc),
        (@margin + @size * hr), hr, hc

    # render grid
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

    # render overlay
    @draw_over ctx


exports.GridDisplay = GridDisplay