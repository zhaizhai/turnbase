assert = require 'assert'
util_m = require 'shared/util.iced'
{M, Adapter} = require 'canvas/mixin.iced'
{property, func, stub} = M

CanvElement = Adapter 'element', {
  requires: {}
  constructor: ->
    @_.dirty = true
  provides:
    parent: property -> null
    width: property -> 0
    height: property -> 0

    set_dirty: (val) ->
      if @_.dirty is val then return
      @_.dirty = val
      if @_.dirty and @parent?
        @parent.set_dirty true
    dirty: -> @_.dirty

    # TODO: we'd like to set_dirty(false) by default here, but for now
    # the dirty flag of leaf nodes don't really matter
    render: stub
    mouse_evt: stub

    get_offset: (ancestor = null) ->
      [x, y] = [0, 0]
      [cur, next] = [@, @parent]
      if not next? then return [x, y]

      while next? and cur isnt ancestor
        [offset_x, offset_y] = next.child_pos cur
        x += offset_x
        y += offset_y
        cur = next
        next = cur.parent
      return [x, y]
}

ChildMap = Adapter 'childmap', {
  requires:
    layout: func
  constructor: ->
    @_.childmap = {}
  provides:
    children: property -> []
    child_pos: (child) ->
      for info in @children
        if info.elt is child
          return [info.x, info.y]
      return null

    set_child: (pos, elt) ->
      # TODO: hacky way of checking if elt is a canvas element
      if elt?
        assert elt.render?, "Invalid element!"

      cm = @_.childmap
      if cm[pos]?
        cm[pos].elt.parent = null

      if elt?
        cm[pos] = {
          elt: elt, x: null, y: null, visible: true
        }
        elt.parent = @
      else
        cm[pos] = null
      # TODO: impose deterministic ordering
      @children = (c for _, c of cm when c?)
      @layout()

    get_child: (pos) ->
      return @_.childmap[pos] ? null
}

ChildList = Adapter 'childlist', {
  requires:
    layout: func
  provides:
    children: property -> []
    child_pos: (child) ->
      for info in @children
        if info.elt is child
          return [info.x, info.y]
      return null
    add_child: (elt, x, y) ->
      # TODO: hacky way of checking if elt is a canvas element
      assert elt.render?, "Invalid element!"

      elt.parent = @
      info = {elt, x, y}
      info.visible = true
      @children.push info
      @layout()
    remove_child: (elt) ->
      @children = (c for c in @children when c.elt isnt elt)
      @layout()
}

ChildRender = Adapter 'childrender', {
  requires:
    children: property
  provides:
    render_children: (ctx) ->
      for child in @children
        {elt, x, y, visible} = child
        if not visible
          continue

        ctx.translate x, y
        elt.render ctx
        elt.set_dirty false
        ctx.translate -x, -y
    child_from_coords: (x, y) ->
      for c in @children.slice().reverse()
        if (c.x <= x and x <= c.x + c.elt.width and
            c.y <= y and y <= c.y + c.elt.height)
          return c
      return null
}


# notifies children of mouse leave events
# TODO: rename?
MouseAdapter = Adapter 'mouse', {
  requires:
    child_from_coords: func
  constructor: ->
    @_.entered = null
  provides:
    mouse_evt: (evt, x, y, props) ->
      if evt is 'leave'
        if @_.entered?
          @_.entered.mouse_evt 'leave', null, null, props
        @_.entered = null
        return

      if not x? or not y?
        throw new Error "wtf"

      child = @child_from_coords x, y
      elt = if child? then child.elt else null

      if @_.entered? and elt isnt @_.entered
        # TODO: maybe report direction of leaving?
        @_.entered.mouse_evt 'leave', null, null, props

      @_.entered = elt
      if elt?
        elt.mouse_evt evt, (x - child.x), (y - child.y), props
}

exports.dirties = (fn) ->
  return (args...) ->
    ret = fn.apply @, args
    @set_dirty true
    return ret

util_m.extend exports, {
  CanvElement, ChildList, ChildMap,
  ChildRender, MouseAdapter
}