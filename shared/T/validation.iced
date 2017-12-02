assert = require 'assert'
mustache_m = require 'mustache'
{T} = require 'shared/T/T.iced'

V = {}
V.r = r = (is_valid, reason = null) ->
  return {outcome: is_valid, reason}


V.Validation = (struct_spec, validations) ->
  # TODO: doesn't work
  struct_validator = V.struct struct_spec._fields
  validator = (x) ->
    result = struct_validator x
    return result if not result.outcome

    for val in validations
      result = val.apply x
      return result if not result.outcome
  return validator

V.extend = (validator, fn) ->
  return (x) ->
    ret = validator x
    return ret unless ret.outcome
    return fn x


V.distinct = (vtype) ->
  validator = V.ArrayOf vtype
  validator = V.extend validator, (x) ->
    len = x.length
    # TODO: not efficient
    for i in [0...len]
      for j in [0...i]
        if x[i] is x[j]
          return r false, "not distinct"
    return r true
  return validator

V.range = (start, end) ->
  return V.extend V.Number, (x) ->
    if x < start or x >= end
      return r false, "#{x} not in range [#{start}, #{end})"
    return r true

# TODO: this doesn't do any meaningful validation
V.Object = (x) ->
  return r true

V.Integer = (x) ->
  if typeof x isnt "number" or (x % 1 isnt 0)
    return r false, "expected #{x} to be integer"
  return r true

V.Boolean = (x) ->
  if typeof x isnt "boolean"
    return r false, "expected #{x} to be boolean"
  return r true

V.Number = (x) ->
  if typeof x isnt "number"
    return r false, "expected #{x} to be number"
  return r true

V.String = (x) ->
  if typeof x isnt "string"
    return r false, "expected #{x} to be string"
  return r true

V.HtmlEscapedString = (x) ->
  return V.String x

V.Nullable = (validator) ->
  ret = (x) ->
    if not x?
      return r true
    return validator x
  ret.base = validator
  return ret

V.ArrayOf = (val_spec) ->
  ArrayOfSpec = (x) ->
    if x not instanceof Array
      return r false, "expected #{x} to be array"
    for elt in x
      ret = val_spec elt
      return ret unless ret.outcome
    return r true
  return ArrayOfSpec

V.struct = (fields) ->
  StructSpec = (x) ->
    for k, v of x
      unless k of fields
        return r false, "unexpected field #{k} in #{x}"

    for k, v of fields
      unless k of x
        return r false, "missing field #{k} in #{x}"
      ret = v x[k]
      return ret unless ret.outcome
    return r true

  return StructSpec


V.verify = (statement, mesg) ->
  if not statement
    return r false, mesg
  return r true

V.check = (check_list) ->
  for item in check_list
    if typeof item is 'function'
      result = item()
      if not result.outcome
        return result
    else
      [bool, reason] = item
      # TODO: should true mean valid or invalid?
      if not bool
        return V.r false, reason
  return V.r true


V._verr = {}
V.catch_asserts = (fn) ->
  return ->
    try
      fn.call(@)
    catch e
      if e isnt V._verr
        throw e
      return V.r false, e.mesg
    return V.r true
V.assert = (assertion, mesg) ->
  if not assertion
    V._verr.mesg = mesg
    throw V._verr


V.validate_request = (request, pattern, coerce_string = false) ->
  # TODO: this is a bit hacky, maybe we should just return args
  # instead
  assert not request.args?
  request.args = {}

  validate_section = (section_name) ->
    for k, p of pattern[section_name]
      val = request[section_name][k]

      try
        # TODO: hack to handle nullable integers
        # TODO: handle other nullable types?
        if p is V.Integer or p.base is V.Integer
          if coerce_string and typeof val is 'string'
            val = parseInt val
        else if p is V.HtmlEscapedString
          val = mustache_m.escape val

        result = p val
        if result.outcome is false
          throw new Error "#{result.reason}"
        request.args[k] = val
      catch e
        return "Error validating #{section_name}.#{k}: #{e.stack}"
    return null

  for section_name of pattern
    err = validate_section section_name
    return err if err
  return null


exports.V = V