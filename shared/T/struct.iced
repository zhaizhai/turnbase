assert = require 'assert'

# TODO: this is already implemented in primitive.iced
is_instance = (x, y) ->
  return typeof y is 'function' and x instanceof y

is_struct = (x) ->
  return x?.constructor?.type is 'struct'

class StructError extends Error
  constructor: (message, @top, @path = []) ->
    super 'abcd'
    Object.defineProperty @, "name", {
      value: @constructor.name
    }
    @base_message = message ? 'StructError'
    @_build_message()
    Error.captureStackTrace @, @constructor

  _build_message: ->
    mesg = """In context #{JSON.stringify @top}\n"""
    if @path.length > 0
      mesg += "\nPath: #{@path}\n\n"
    mesg += "#{@base_message}"
    Object.defineProperty @, "message", {value: mesg}

  prepend_path: (component) ->
    @path = [component].concat @path
    @_build_message()
    return @

  set_top: (@top) ->
    @_build_message()
    return @

# T.get_field_type = (type_spec, field_name) ->
#   if type_spec.type == 'array'
#     assert typeof field_name is 'number'
#     return type_spec._elt
#   if type_spec.type == 'struct'
#     return type_spec._fields[field_name]
#   throw new Error "type #{type_spec.type} doesn't have fields!"

struct = (name, all_fields, opts) ->
  opts ?= {}

  # TODO: slight hack
  fields = {}
  funcs = {}
  for k, v of all_fields
    if typeof v is 'function'
      if v.type?
        fields[k] = v
      else
        funcs[k] = v
    else
      throw new Error "Field \"#{k}\" of #{name} does not specify a valid struct property"

  class Struct
    @dump_json = (obj, mask = null) ->
      ret = {}
      for k, v of fields
        try
          ret[k] = v.dump_json obj[k], mask
        catch e
          if e instanceof StructError
            e.set_top obj
            e.prepend_path k
          else
            e = new StructError e.message, obj, [k]
          throw e
      return ret

    @load_json = (json) ->
      # TODO: validate that it's a plain object?
      return new Struct json

    constructor: (json) ->
      if opts.loaders?
        # try out custom loaders
        for loader in opts.loaders
          if loader.apply @, arguments
            return

      for k of fields
        if k not of json
          throw new StructError "Error in struct #{Struct._name}: missing field \"#{k}\"", json

      for k, v of json
        if k not of fields
          throw new StructError "Error in struct #{Struct._name}: Unexpected field \"#{k}\"", json

        try
          if is_instance v, fields[k]
            # TODO: handle arrays and primitives
            @[k] = v
          else
            @[k] = fields[k].load_json v

        catch e
          if e instanceof StructError
            e.set_top json
            e.prepend_path k
          else
            e = new StructError e.message, json, [k]
          throw e


  Struct._name = name
  Struct._fields = {}
  for k, v of fields
    Struct._fields[k] = v

  for k, v of funcs # TODO: will this work?
    Struct.prototype[k] = v
  Struct.type = 'struct'

  for k, v in funcs # TODO: check this is right
    Struct.prototype[k] = v
  return Struct



# TODO: untested
struct.augments = (name, base_struct, new_fields) ->
  # TODO: slight hack
  all_fields = {}
  funcs = {}
  for k, v of new_fields
    if typeof v is 'function' and not v.type?
      funcs[k] = v
    else
      all_fields[k] = v

  for k, v of base_struct._fields
    if k of all_fields
      throw new StructError "Field #{k} conflicts with base struct"
    all_fields[k] = v

  ret = struct name, all_fields
  for k, v of funcs
    ret.prototype[k] = v
  ret._base = base_struct
  # TODO: more stuff?
  return ret



# TODO: untested
struct.transition = (from_type, to_type, obj, args) ->
  assert obj.constructor is from_type

  augments_chain = (t) ->
    ret = [t]
    while t._base?
      ret = [t._base].concat ret

  from_chain = augments_chain from_type
  to_chain = augments_chain to_type

  get_lca = (chain1, chain2) ->
    len = Math.min chain1.length, chain2.length
    if chain1[0] isnt chain2[0]
      return null
    idx = 0
    while idx < len - 1 and chain1[idx + 1] is chain2[idx + 1]
      idx++
    return chain1[idx]

  lca = get_lca from_chain, to_chain
  lca_fields = if lca? then lca._fields else {}

  extra = {}
  for k, v of to_type._fields
    if k not of lca_fields
      extra[k] = v

  json = {}
  for k, v of lca_fields
    json[k] = obj[k]

  for k, v of args
    if k not of extra
      throw new Error "Extraneous argument #{k}"

  for k, v of extra
    if k not of args
      throw new Error "Missing argument #{k}"
    json[k] = args[k]

  return new to_type json


exports.struct = struct
