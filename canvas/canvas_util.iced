roundRectPath = (ctx, x, y, width, height, radius) ->
  ctx.lineWidth = 1
  ctx.beginPath()
  ctx.moveTo (x + radius), y
  ctx.lineTo (x + width - radius), y
  ctx.quadraticCurveTo (x + width), y, (x + width), (y + radius)
  ctx.lineTo (x + width), (y + height - radius)
  ctx.quadraticCurveTo (x + width), (y + height), (x + width - radius), (y + height)
  ctx.lineTo (x + radius), (y + height)
  ctx.quadraticCurveTo x, (y + height), x, (y + height - radius)
  ctx.lineTo x, (y + radius)
  ctx.quadraticCurveTo x, y, (x + radius), y
  ctx.closePath()

exports.strokeRoundRect = strokeRoundRect = (ctx, x, y, width, height, radius) ->
  roundRectPath ctx, x, y, width, height, radius
  ctx.stroke()

exports.fillRoundRect = fillRoundRect = (ctx, x, y, width, height, radius) ->
  roundRectPath ctx, x, y, width, height, radius
  ctx.fill()

exports.draw_disk = draw_disk = (ctx, x, y, r, color, border = null) ->
  ctx.fillStyle = color
  ctx.strokeStyle = border ? 'black'
  ctx.beginPath()
  ctx.arc x, y, r, 0, (2 * Math.PI)
  ctx.fill()
  ctx.stroke()


exports.draw_centered_img = draw_centered_img = (ctx, img, x, y, scale = 1) ->
  [w, h] = [img.width * scale, img.height * scale]
  ctx.drawImage img, (x - w/2), (y - h/2), w, h

exports.in_range = in_range = (x, y, rect) ->
  return (x >= rect[0] and x <= rect[2] and
          y >= rect[1] and y <= rect[3])

exports.clip = clip = (ctx, bounds) ->
  [x, y, w, h] = bounds
  ctx.beginPath()
  ctx.moveTo x, y
  ctx.lineTo x + w, y
  ctx.lineTo x + w, y + h
  ctx.lineTo x, y + h
  ctx.lineTo x, y
  ctx.clip()

exports.darken = darken = (color, ratio) ->
  ret = '#'
  color = color.slice 1
  for i in [0...3]
    val = color.slice (2 * i), (2 * i + 2)
    val = parseInt val, 16
    val = Math.floor (val * ratio)
    val = val.toString 16
    val = '0' + val if val.length is 1
    ret += val
  return ret

exports.wrap_text = wrap_text = (ctx, text, max_width) ->
  cur_chunk = {txt: '', pad: ''}
  chunks = [cur_chunk]

  for c in text
    if c in ' \n'
      cur_chunk.pad += c
    else if cur_chunk.pad.length > 0
      cur_chunk = {txt: c, pad: ''}
      chunks.push cur_chunk
    else
      cur_chunk.txt += c

  cur_block = ''
  cur_pad = ''
  ret = []
  for chunk in chunks
    line = cur_block + cur_pad + chunk.txt
    if ctx.measureText(line).width > max_width and cur_block.length > 0
      ret.push cur_block
      cur_block = chunk.txt
    else
      cur_block += cur_pad + chunk.txt
    cur_pad = chunk.pad

  ret.push cur_block
  return ret


class BufferedCanvas
  # A double-buffered HTML5 Canvas.

  constructor: (@width, @height) ->
    @_elt = $("<canvas width=\"#{@width}\" height=\"#{@height}\">")
    @_buf = $("<canvas width=\"#{@width}\" height=\"#{@height}\">").get 0

    @_mouse_pressed = false # our best guess as to whether mouse is currently pressed
    $(document.body).mousedown (e) =>
      @_mouse_pressed = true
    $(document.body).mouseup (e) =>
      @_mouse_pressed = false

  standardize_evt = (e) ->
    return {
      x: e.offsetX ? (e.clientX - $(e.target).offset().left)
      y: e.offsetY ? (e.clientY - $(e.target).offset().top)
      right: (e.which is 3)
    }

  click: (handler) ->
    @_elt.click (e) =>
      e = standardize_evt e
      return handler e.x, e.y, {right: e.right}

  mousemove: (handler) ->
    @_elt.mousemove (e) =>
      e = standardize_evt e
      return handler e.x, e.y, {pressed: @_mouse_pressed}

  mousedown: (handler) ->
    @_elt.mousedown (e) =>
      e = standardize_evt e
      return handler e.x, e.y, {}

  mouseup: (handler) ->
    @_elt.mouseup (e) =>
      e = standardize_evt e
      return handler e.x, e.y, {}

  swap: ->
    ctx = @_elt.get(0).getContext '2d'
    ctx.drawImage @_buf, 0, 0

  clear: ->
    @ctx().clearRect 0, 0, @width, @height

  ctx: -> (@_buf.getContext '2d')

  elt: -> @_elt


exports.BufferedCanvas = BufferedCanvas