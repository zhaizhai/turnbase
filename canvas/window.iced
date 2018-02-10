canvas_util_m = require 'canvas/canvas_util.iced'
measure_m = require 'canvas/measure.iced'

{MixinClass} = require 'canvas/mixin.iced'
{
  CanvElement, ChildList, MouseAdapter,
  ChildRender, dirties
} = require 'canvas/adapter.iced'

InvisibleBox = MixinClass 'InvisibleBox', [CanvElement],
  constructor: (width, height) ->
    @width = width
    @height = height

  layout: ->
    @set_dirty true
    @parent.layout() if @parent?

  mouse_evt: (evt, x, y) ->

  render: (ctx) ->


DEFAULT_TEXT_BOX_OPTS = {
  size: 15, text_color: 'black',
  font: 'Roboto', align: 'left'
  style: ''
}
TextBox = MixinClass 'TextBox', [CanvElement],
  constructor: (opts) ->
    for k, v of DEFAULT_TEXT_BOX_OPTS
      @[k] = opts[k] ? v
    @text_lines = (opts.text?.split '\n') ? []
    @layout()

  set_text: (text) ->
    @text_lines = (text?.split '\n') ? []
    @layout()

  layout: ->
    @height = @size * (@text_lines.length * 1.2 - 0.2)
    @height = Math.max 0, @height
    @width = 0
    for line in @text_lines
      line_w = measure_m.text_width line, {@size, @font}
      @width = Math.max @width, line_w

    @set_dirty true
    @parent.layout() if @parent?

  mouse_evt: (evt, x, y) ->

  render: (ctx) ->
    ctx.fillStyle = @text_color
    ctx.font = "#{@style} #{@size}pt #{@font}"
    ctx.textAlign = @align
    x = switch @align
      when 'left'
        0
      when 'center'
        (@width / 2)
      else
        throw new Error "TODO: can't handle @align = #{@align}"
    for line, idx in @text_lines
      ctx.fillText line, x, (@size * (idx * 1.2 + 1))


# TODO: clean up
MultiStyleTextBox = MixinClass 'MultiStyleTextBox', [CanvElement],
  constructor: (opts) ->
    {@size, @num_rows} = opts
    @size ?= 15
    @num_rows ?= 1

    @bg_color = 'white'
    @line_spacing = 3
    @part_spacing = 3
    @default_font = 'Roboto'
    @default_text_color = 'black'
    @parts = null
    @width = opts.width ? 80

  layout: ->
    @height = @size * @num_rows + @line_spacing * @num_rows
    @set_dirty true
    @parent.layout() if @parent?

  # parts is an array of {text, font, color}
  set_parts: (@parts) ->

  mouse_evt: (evt, x, y) ->

  render: (ctx) ->
    if not @parts?
      return

    ctx.fillStyle = @bg_color
    ctx.fillRect 0, 0, @width, @height

    ctx.lineWidth = 3
    ctx.strokeStyle = '#EEEEEE'
    ctx.strokeRect 0, 0, @width, @height

    ctx.textAlign = 'left'
    x = 0
    y = @size
    row = 0

    for part in @parts
      {color, font, text} = part
      color ?= @default_text_color
      font ?= @default_font

      ctx.fillStyle = color
      ctx.font = "#{@size}pt #{font}"
      text_width = (ctx.measureText text).width

      # go to next row?
      # TODO: enforce number of rows limit
      if text_width + x > @width
        row += 1
        x = 0
        y += @line_spacing + @size

      # console.log "Printing #{text} at #{x}, #{y}"
      ctx.fillText text, x, y
      x += text_width + @part_spacing


TextInfo = MixinClass 'TextInfo', [CanvElement],
  constructor: (@_info) ->
    # TODO: fix an ordering on _info
    @_text_size = 10 # TODO: make customizable
    @layout()

  set_info: (info_map) ->
    for k, v of info_map
      @_info[k] = v
    @layout()

  layout: ->
    @height = @_text_size * (k for k of @_info).length
    @width = 80 # TODO
    @set_dirty true
    @parent.layout() if @parent?

  mouse_evt: (evt, x, y) ->

  render: (ctx) ->
    y = @_text_size
    for k, v of @_info
      unless v? then continue
      text = "#{k}: #{v}"
      ctx.font = @_text_size + 'pt Roboto'
      ctx.fillStyle = 'black'
      ctx.textAlign = 'left'
      ctx.fillText text, 0, y
      y += @_text_size

Button = MixinClass 'Button', [CanvElement],
  constructor: (opts) ->
    {@text, @size, @bg_color} = opts
    @size ?= 12
    @bg_color ?= '#DDDDDD'
    @font = 'Roboto'

    @handler = opts.handler ? null
    @_onpress = opts.onpress ? null
    @_onrelease = opts.onrelease ? null
    @_disabled = opts.disabled ? false

    @_pressed = false
    @_hover = false

    {@width, @height} = opts
    @height ?= (@size + 6)
    if not @width?
      text_width = measure_m.text_width @text, {@size, @font}
      @width = (text_width + 6)

  disable: dirties ->
    # TODO: reset hover and pressed states?
    @_disabled = true

  enable: dirties ->
    @_disabled = false

  mouse_evt: (evt, x, y, props) ->
    if evt is 'move'
      if not @_hover then @set_dirty true
      @_hover = true
      if not @_pressed and props.pressed
        @_pressed = true
        @_onpress?()
      return
    if evt is 'leave'
      if @_hover then @set_dirty true
      @_hover = false
      if @_pressed
        @_pressed = false
        @_onrelease?()
      return
    if @_disabled then return

    if evt is 'click'
      return @handler?()
    if evt is 'down'
      if not @_pressed # TODO: is this ever not the case?
        @_pressed = true
        @_onpress?()
      return
    if evt is 'up'
      if @_pressed
        @_pressed = false
        @_onrelease?()
      return @_onmouseup?()

  render: (ctx) ->
    bg = @bg_color
    if @_hover and not @_disabled
      bg = canvas_util_m.darken bg, 0.8
    ctx.fillStyle = bg
    canvas_util_m.fillRoundRect ctx,
      0, 0, @width, @height, 3

    # hopefully 20pt -> 20 pixels
    ctx.font = "#{@size}pt #{@font}"
    ctx.fillStyle = (if @_disabled then 'gray' else 'black')
    ctx.textAlign = 'center'

    wrapped = canvas_util_m.wrap_text ctx, @text, (@width - 6)
    vsep = @size + 2
    offset_y = (@height - (wrapped.length - 1) * vsep - @size) / 2
    for line, idx in wrapped
      y = offset_y + idx * vsep + @size
      ctx.fillText line, (@width / 2), y


exports.render_loop = (canv, root, fps) ->
  canv.click (x, y, props) ->
    root.mouse_evt 'click', x, y, props
  canv.mousemove (x, y, props) ->
    root.mouse_evt 'move', x, y, props
  canv.mousedown (x, y, props) ->
    root.mouse_evt 'down', x, y, props
  canv.mouseup (x, y, props) ->
    root.mouse_evt 'up', x, y, props

  delay = 1000 / fps
  do_render = ->
    if root.dirty()
      console.log 'rendering'
      canv.clear()
      ctx = canv.ctx()
      root.render ctx
      root.set_dirty false
      # XXX: This setTimeout seems to be necessary in order to
      # guarantee that the rendering actually happens. I am not sure
      # if this is a browser bug, or if this is allowed by the HTML
      # canvas standard.
      await setTimeout defer(), 0
      canv.swap()
    setTimeout do_render, delay
  root.set_dirty true
  do_render()

exports.InvisibleBox = InvisibleBox
exports.MultiStyleTextBox = MultiStyleTextBox
exports.TextBox = TextBox
exports.TextInfo = TextInfo
exports.Button = Button
