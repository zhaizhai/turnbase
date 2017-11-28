assert = require 'assert'
util_m = require 'shared/util.iced'

{MixinClass} = require 'canvas/mixin.iced'
{CanvElement, ChildList, MouseAdapter, ChildRender, ChildMap} = require 'canvas/adapter.iced'

HBox = MixinClass 'HBox', [
  CanvElement, ChildList, MouseAdapter,
  ChildRender
],
  constructor: (opts, child_elts = null) ->
    {@spacing, @min_height} = opts
    @spacing ?= 10
    @min_height ?= 0

    if child_elts?
      for elt in child_elts
        @add elt

  add: (elt) ->
    @add_child elt, null, null
    @layout()

  set_visible: (idx, val) ->
    if @children[idx].visible is val
      return
    @children[idx].visible = val
    @layout()

  layout: ->
    [x, y] = [0, 0]
    ymax = Math.max.apply null, (c.elt.height for c in @children when c.visible)
    ymax = Math.max ymax, @min_height
    num_visible = 0
    for child, idx in @children
      if child.visible
        child.y = (ymax - child.elt.height) / 2
        child.x = x
        x += @spacing + child.elt.width
        num_visible += 1
      else
        child.y = child.x = null

    if num_visible == 0
      @width = 0
      @height = 0
    else
      @width = x - @spacing
      @height = ymax

    @set_dirty true
    @parent.layout() if @parent?

  render: (ctx) ->
    @render_children ctx


VBox = MixinClass 'VBox', [
  CanvElement, ChildList, MouseAdapter,
  ChildRender
],
  constructor: (opts, child_elts = null) ->
    {@spacing, @min_width} = opts
    @spacing ?= 10
    @min_width ?= 0

    if child_elts?
      for elt in child_elts
        @add elt

  set_visible: (idx, val) ->
    if @children[idx].visible is val
      return
    @children[idx].visible = val
    @layout()

  add: (elt) ->
    @add_child elt, null, null
    @layout()

  layout: ->
    [x, y] = [0, 0]
    xmax = Math.max.apply null, (c.elt.width for c in @children)
    xmax = Math.max xmax, @min_width
    num_visible = 0
    for child, idx in @children
      if child.visible
        child.x = (xmax - child.elt.width) / 2
        child.y = y
        y += @spacing + child.elt.height
        num_visible += 1
      else
        child.y = child.x = null

    if num_visible == 0
      @width = @min_width
      @height = 0
    else
      @width = xmax
      @height = y - @spacing

    @set_dirty true
    @parent.layout() if @parent?

  render: (ctx) ->
    @render_children ctx


# TODO: accommodate multiple draw overs
OverlayContainer = MixinClass 'OverlayContainer', [
  CanvElement, ChildList, ChildRender, MouseAdapter
],
  constructor: (child, @draw_over = null) ->
    @add_child child, 0, 0
    @layout()
  set_draw_over: (@draw_over) ->
  layout: ->
    @width = @children[0].elt.width
    @height = @children[0].elt.height
    @parent?.layout()
  render: (ctx) ->
    @render_children ctx
    if @draw_over?
      @draw_over ctx


# LLTTTTRR
# LLTTTTRR
# LLCCCCRR
# LLCCCCRR
# LLCCCCRR
# LLBBBBRR
# LLBBBBRR
POSITIONS = ['left', 'right', 'top', 'bottom', 'center']
BorderFrame = MixinClass 'BorderFrame', [
  CanvElement, ChildMap, ChildRender, MouseAdapter
],
  constructor: (opts) ->
    {@forced_dims, @background, @border} = opts
    # TODO: validate @forced_dims is {width, height}

    # TODO: might want to avoid the extraneous @layout() calls from
    # @set_child
    for pos in POSITIONS
      @set_child pos, (opts[pos] ? null)

  set_opts: (opts) ->
    {@background, @border} = opts
    @layout()

  layout: ->
    [left, right, top, bottom, center] =
      (@get_child pos for pos in POSITIONS)

    [tw, th] = if top? then [top.elt.width, top.elt.height] else [0, 0]
    [bw, bh] = if bottom? then [bottom.elt.width, bottom.elt.height] else [0, 0]
    [lw, lh] = if left? then [left.elt.width, left.elt.height] else [0, 0]
    [rw, rh] = if right? then [right.elt.width, right.elt.height] else [0, 0]
    [cw, ch] = if center? then [center.elt.width, center.elt.height] else [0, 0]

    if @forced_dims?
      @width = @forced_dims.width
      @height = @forced_dims.height
    else
      @width = lw + rw + (Math.max tw, bw, cw)
      @height = Math.max lh, rh, (th + ch + bh)
    cw_full = @width - lw - rw
    ch_full = @height - th - bh

    if left?
      dh = (@height - lh) / 2
      [left.x, left.y] = [0, dh]
    if right?
      dh = (@height - rh) / 2
      [right.x, right.y] = [(@width - rw), dh]
    if top?
      dw = (cw_full - tw) / 2
      [top.x, top.y] = [(lw + dw), 0]
    if bottom?
      dw = (cw_full - bw) / 2
      [bottom.x, bottom.y] = [(lw + dw), (@height - bh)]
    if center?
      dw = (cw_full - cw) / 2
      dh = (ch_full - ch) / 2
      [center.x, center.y] = [(lw + dw), (th + dh)]

    @set_dirty true
    @parent.layout() if @parent?

  render: (ctx) ->
    if @background?
      ctx.fillStyle = @background
      ctx.fillRect 0, 0, @width, @height

    @render_children ctx

    if @border?
      ctx.strokeStyle = @border
      ctx.lineWidth = 1
      ctx.strokeRect 0, 0, @width, @height


Frame = MixinClass 'Frame', [
  CanvElement, ChildList, ChildRender, MouseAdapter
],
  constructor: (opts) ->
    {@width, @height, @background, @margin} = opts
    # TODO: implement margin

  layout: ->
    @parent.layout() if @parent?
    @set_dirty true

  add: (elt, x, y) ->
    @add_child elt, x, y

  render: (ctx) ->
    if @background?
      ctx.fillStyle = @background
      ctx.fillRect 0, 0, @width, @height
    @render_children ctx

util_m.extend exports, {
  Frame, BorderFrame, HBox, VBox,
  OverlayContainer
}
