# RenderChildren =
#   deps: [ChildMap, ChildList]

#   constructor: ->

#   render: (ctx) ->
#     for {x, y, elt} in @__children
#       ctx.translate x, y
#       elt.render ctx
#       ctx.translate -x, -y

# class ChildMap
#   constructor: ->
#     @_children = {}

#   children: ->

# class ChildList
#   constructor: ->


mixin = (obj, adapter) ->
  name = adapter.name
  adapter_obj = new adapter

  # TODO: throw informative errors if dependencies missing
  for req in adapter.reqs
    adapter_obj[req] = (obj[req].bind obj)
  # obj['__' + name] = adapter_obj

  # TODO: allow customization
  for impl in adapter.impls
    obj[impl] = (adapter_obj[impl].bind adapter_obj)

provides = requires = (args...) ->
  return args

adapter = (name, impls, reqs, funcs) ->
  ret = class Adapter
    constructor: ->
      funcs.constructor.apply @, []

  for k, v of funcs
    if k isnt 'constructor'
      ret.prototype[k] = v
  ret.name = name
  ret.reqs = reqs
  ret.impls = impls
  return ret

MouseAdapter = adapter 'mouse', (provides 'mouse_evt'),
  (requires 'child_from_coords'), {
    constructor: ->
      @_entered = null

    mouse_evt: (evt, x, y) ->
      if evt is 'leave'
        if @_entered?
          @_entered.mouse_evt 'leave', null, null
        @_entered = null
        return

      child = @child_from_coords x, y
      elt = if child? then child.elt else null

      if @_entered? and elt isnt @_entered
        # TODO: maybe report direction of leaving?
        @_entered.mouse_evt 'leave', null, null

      @_entered = elt
      if elt?
        elt.mouse_evt evt, (x - child.x), (y - child.y)
  }

exports.mixin = mixin
exports.MouseAdapter = MouseAdapter
