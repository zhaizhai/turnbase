html_util_m = require 'client/lib/html_util.iced'
{make_elt} = html_util_m

class EltDisplay
  TMPL = '''<div></div>'''
  HEADER_TMPL = '''<div class="canv-elt">{{elt_type}}<div>'''
  CHILDREN_TMPL = '''<div class="canv-children"></div>'''

  constructor: (@root, @canvas, @canv_elt) ->
    @_header = make_elt HEADER_TMPL, {
      elt_type: @canv_elt.constructor.name
    }
    @_header.hover (@hover_in.bind @), (@hover_out.bind @)
    @_children = make_elt CHILDREN_TMPL
    @_children.css 'margin-left', '20px'

    @_elt = (make_elt TMPL).append(@_header).append(@_children)
    return unless @canv_elt.children?
    for child in @canv_elt.children
      @_children.append (new EltDisplay @root, @canvas, child.elt).elt()
    # TODO: handle ChildMaps differently

  # TODO: deal with animations
  hover_in: ->
    @_header.css 'background-color', '#AAAAFF'
    window.cur_elt = @canv_elt

    ctx = @canvas.ctx()
    @root.render ctx
    console.log "Canvas Debugger:", @canv_elt

    [x, y] = @canv_elt.get_offset()
    ctx.save()
    ctx.globalAlpha = 0.5
    ctx.fillStyle = 'blue'
    ctx.fillRect x, y, @canv_elt.width, @canv_elt.height
    ctx.restore()
    @canvas.swap()

  hover_out: ->
    @_header.css 'background-color', ''
    ctx = @canvas.ctx()
    @root.render ctx
    @canvas.swap()

  elt: -> @_elt

class CanvasDebugger
  TMPL = '''
  <div>
  </div>
  '''

  constructor: (@canvas) ->
    if not @canvas?
      throw new Error "Missing canvas!"

  debug: (root) ->
    elt = make_elt TMPL
    elt.css {
      position: 'fixed'
      top: '20px'
      right: '20px'
      'z-index': '1000'
      'background-color': '#DDDDDD'
      margin: '5px'
      'border-radius': '3px'
      border: 'solid black 1px'
    }
    root_disp = new EltDisplay root, @canvas, root
    elt.append root_disp.elt()

    ($ document.body).append elt

exports.CanvasDebugger = CanvasDebugger

