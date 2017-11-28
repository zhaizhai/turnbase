assert = require 'assert'

{T} = require 'shared/T/T.iced'
{V} = require 'shared/T/validation.iced'

class AppRouter
  constructor: ->
    @_get = {}
    @_post = {}

  _with_validation: (validation, handler, coerce_string = false) ->
    fn = (req, res) =>
      validation_result = V.validate_request req, validation, coerce_string
      if validation_result?
        return res.status(400).send(validation_result)
      return handler req, res
    return fn

  post: (url, validation, handler) ->
    @_post[url] = (@_with_validation validation, handler)

  get: (url, validation, handler) ->
    @_get[url] = (@_with_validation validation, handler, true)

  connect: (app, with_prefix) ->
    make_full = (url) ->
      ret = with_prefix
      ret += url unless url is '/'
      return ret

    for url, handler of @_get
      app.get (make_full url), handler
    for url, handler of @_post
      app.post (make_full url), handler

exports.AppRouter = AppRouter