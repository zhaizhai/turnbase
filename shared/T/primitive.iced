is_instance = (x, y) ->
  return typeof y is 'function' and x instanceof y

T = {}
id = (x) -> x

# TODO: this doesn't do any meaningful validation
T.Object = id
T.Object.load_json = id
T.Object.dump_json = (x) ->
  return JSON.parse (JSON.stringify x)
T.Object.type = 'object'

T.Number = (x) ->
  if typeof x isnt 'number'
    throw new Error "expected number #{x}"
  return x
T.Number.load_json = T.Number
T.Number.dump_json = id
T.Number.type = 'number'

T.Integer = (x) ->
  if typeof x isnt 'number' or (x % 1 isnt 0)
    throw new Error "expected integer #{x}"
  return x
T.Integer.load_json = T.Integer
T.Integer.dump_json = id
T.Integer.type = 'number'

T.Boolean = (x) ->
  if typeof x isnt 'boolean'
    throw new Error "expected boolean #{x}"
  return x
T.Boolean.load_json = T.Boolean
T.Boolean.dump_json = id
T.Boolean.type = 'boolean'

T.String = (x) ->
  if typeof x isnt 'string'
    throw new Error "expected string #{x}"
  return x
T.String.load_json = T.String
T.String.dump_json = id
T.String.type = 'string'

T.Nullable = (type_spec) ->
  # TODO: hax way to make copy of type_spec, also do we need
  # prototype?
  ret = ->
    throw new Error "Cannot call constructor of nullable type"
  for k, v of type_spec
    ret[k] = v
  # TODO: record type_spec

  ret.dump_json = (obj, mask = null) ->
    if not obj?
      return null
    return type_spec.dump_json obj, mask

  ret.load_json = (json) ->
    if not json?
      return null
    if is_instance json, type_spec
      return json
    return type_spec.load_json json
  return ret

T.ArrayOf = (type_spec) ->
  ArrayOfSpec = (arr) ->
    if not arr instanceof Array
      throw new Error "expected #{arr} to be array!"
    for elt in arr
      type_spec elt
    return arr
  ArrayOfSpec.load_json = (json) ->
    if not json instanceof Array
      throw new Error "expected #{arr} to be array!"
    ret = []
    for elt in json
      loaded_elt = elt
      unless typeof type_spec is 'function' and elt instanceof type_spec
        loaded_elt = type_spec.load_json elt
      ret.push loaded_elt
    return ret
  ArrayOfSpec.dump_json = (x, mask = null) ->
    ret = []
    for elt in x
      ret.push type_spec.dump_json elt, mask
    return ret
  ArrayOfSpec.type = 'array'
  ArrayOfSpec._elt = type_spec
  return ArrayOfSpec

exports.T = T