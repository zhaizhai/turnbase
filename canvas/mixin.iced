property = (init) ->
  init.__marker = 'property'
  return init
func = {}
stub = ->
stub.__marker = 'stub'

Adapter = (name, spec) ->
  spec.name = name
  return spec


_mixin_adapter = (obj_type, adapter) ->
  name = '__' + adapter.name
  proto = obj_type.prototype

  for impl, func of adapter.provides
    if func.__marker is 'property'
      continue

    if proto[impl]?
      if func.__marker is 'stub'
        continue
      unless proto[impl].__marker is 'stub'
        throw new Error "interface collision (from #{adapter.name}): method #{impl}!"

    do (impl, func) ->
      proto[impl] = (args...) ->
        old_ = @_
        @_ = @[name]
        ret = func.apply @, args
        @_ = old_
        return ret
      if func.__marker is 'stub'
        proto[impl].__marker = 'stub'

MixinClass = (name, adapters, spec) ->
  props = {}
  for adapter in adapters
    for impl, func of adapter.provides
      if func.__marker isnt 'property'
        continue
      if props[impl]?
        throw new Error "interface collision: property #{impl}"
      props[impl] = func

  init_adapters = ->
    for k, v of props
      @[k] = v()
    for adapter in adapters
      livein = @['__' + adapter.name] = {}
      @_ = livein
      adapter.constructor.apply @, []
      @_ = null

  validate_props = ->
    for adapter in adapters
      for impl, func of adapter.requires
        if func.__marker isnt 'property' then continue
        if impl not of @
          throw new Error "missing requirement: property #{impl}"

  ret = (args...) ->
    init_adapters.apply @, []
    spec.constructor.apply @, args
    validate_props()
    return @

  # a hack to get the desired name
  rename_func = (fn, new_name) ->
    eval_str = """
      return function (call) {
        return function #{new_name}() {
          return call(this, arguments);
        };
      };"""
    return (new Function(eval_str)())(Function.apply.bind(fn));
  ret = rename_func ret, name

  for k, v of spec
    if k is 'constructor' then continue
    ret.prototype[k] = v

  for adapter in adapters
    _mixin_adapter ret, adapter

  for adapter in adapters
    for impl, func of adapter.requires
      if func is property
        continue
      if not ret.prototype[impl]?
        throw new Error """
          missing requirement \
          (from #{adapter.name}): \
          method #{impl}"""
  return ret

exports.MixinClass = MixinClass
exports.Adapter = Adapter
exports.M = {property, func, stub}