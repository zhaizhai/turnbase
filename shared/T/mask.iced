assert = require 'assert'
{extend} = require 'shared/util.iced'

primitive_m = require 'shared/T/primitive.iced'
{struct} = require 'shared/T/struct.iced'

_T = {}
extend _T, primitive_m.T

T = {}
T.MaskedObj = (masked_type) ->
  @type = masked_type
  return @
T.MaskedObj.prototype.toString = T.MaskedObj.prototype.inspect = -> # TODO: temp hack
  return '<__masked__>'

T.is_masked = (x) ->
  return x instanceof T.MaskedObj

T.MaskedStruct = (type_spec) ->
  # TODO: hax way to make copy of type_spec
  MType = (args...) ->
    type_spec.apply @, args
    @_access = []
    return @

  # TODO: does this work?
  for k, v of type_spec
    MType[k] = v
  # TODO: hack
  MType._name = 'M' + MType._name

  for k, v of type_spec.prototype
    MType.prototype[k] = v

  MType.unmask = (obj) ->
    # TODO: asssert obj is of appropriate type?
    if obj instanceof T.MaskedObj
      throw new StructError "Cannot unmask #{obj}"
    json = MType.dump_json obj
    delete json._access
    return (type_spec.load_json json)

  MType.dump_json = (obj, mask = null) ->
    # doesn't mask unless you specifically request it
    if mask?
      if not obj._access?
        throw new StructError "Masked object is missing _access property", obj
      if mask not in obj._access
        return '__masked__'

    if obj instanceof T.MaskedObj
      # # TODO: maybe this should be an error
      # throw new StructError "Trying to serialize masked object but no mask specified!", obj
      return '__masked__'

    json = type_spec.dump_json obj, mask
    json._access = obj._access
    return json

  MType.load_json = (json) ->
    if json is '__masked__'
      return new T.MaskedObj MType

    _access = json._access ? []
    delete json._access
    ret = new MType json
    ret._access = _access
    return ret

  # MType.prototype.reveal = (new_access, json) ->
  #   @_access = new_access # TODO..

  MType.prototype.has_access = (x) ->
    return x in @_access

  MType.prototype.add_access = (x) ->
    unless x in @_access
      @_access.push x
    return @

  # TODO: MType.type = ?
  return MType


T.MString = T.MaskedString = T.MaskedStruct (struct 'StringContainer', {
  s: _T.String
  get: -> @s
  set: (@s) ->
}, {
  loaders: [
    (s) ->
      return false if typeof s isnt 'string'
      @s = s
      return true
    ]
})

T.MInteger = T.MaskedInteger = T.MaskedStruct (struct 'IntegerContainer', {
  n: _T.Integer
  get: -> @n
  set: (@n) ->
}, {
  loaders: [
    (n) ->
      return false if typeof n isnt 'number' or (n % 1 isnt 0)
      @n = n
      return true
    ]
})

T.MNumber = T.MaskedNumber = T.MaskedStruct (struct 'NumberContainer', {
  n: _T.Number
  get: -> @n
  set: (@n) ->
}, {
  loaders: [
    (n) ->
      return false if typeof n isnt 'number'
      @n = n
      return true
    ]
})

T.MBoolean = T.MaskedBoolean = T.MaskedStruct (struct 'BooleanContainer', {
  b: _T.Boolean
  get: -> @b
  set: (@b) ->
}, {
  loaders: [
    (b) ->
      return false if typeof b isnt 'boolean'
      @b = b
      return true
    ]
})

T.Masked = (type_spec) ->
  # TODO: does this work for Nullable primitives?
  switch type_spec.type
    when 'string'
      return T.MaskedString
    when 'number'
      return T.MaskedNumber
    when 'boolean'
      return T.MaskedBoolean
    when 'struct'
      return T.MaskedStruct type_spec
    else
      throw new Error "Do not know how to mask type #{type_spec.type}"

exports.T = T