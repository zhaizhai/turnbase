http_m = require 'http'
querystring_m = require 'querystring'
readline_m = require 'readline'

# We are OK with having many longpoll connections to our own server.
# TODO: monitor number of sockets in use to help detect resource leaks
# TODO: consider using a non-global http agent
http_m.globalAgent.maxSockets = 100

# Client libraries depend on $.ajax to make requests. This is a
# substitute so that bots can use the same libraries without running
# in the browser.
#
# TODO: We should do a more explicit dependency injection so that 1)
# it's clearer that $.ajax is the only JQuery API we're using and 2)
# the code can be a bit cleaner as the $.ajax API is slightly
# cumbersome.
global.$ =
  hostname: 'localhost'
  signed_cookie: null
  ajax: (params) ->
    {url, type, contentType, data, success, error} = params
    type = type.toUpperCase()
    headers =
      Connection: 'keep-alive'
      'Content-Type': 'application/json'
    if $.signed_cookie?
      headers.Cookie = $.signed_cookie

    opts =
      pool: false
      hostname: $.hostname
      port: 8888
      path: url
      method: type
      headers: headers
    if type is 'GET'
      opts.path += '?' + querystring_m.stringify data

    req = http_m.request opts, (res) ->
      # console.log 'STATUS: ', res.statusCode
      # console.log 'HEADERS: ', (JSON.stringify res.headers)
      set_cookie = res.headers['set-cookie']
      if set_cookie?
        $.signed_cookie = set_cookie[0]
        console.log 'cookie now', $.signed_cookie

      res.setEncoding 'utf8'
      res_data = ''
      res.on 'data', (chunk) ->
        res_data += chunk
      res.on 'end', ->
        # TODO: this is kind of weird, but it seems to match jquery's
        # behavior
        try
          ret_data = (JSON.parse res_data)
        catch e
          ret_data = res_data
        status = res.statusCode
        if status isnt 200
          return error {status}, status, ret_data

        # console.log '$.ajax success', ret_data
        return success ret_data, status, {status}

    aborted = false
    req.on 'error', (e) ->
      if aborted then return
      # TODO: I don't think this reports the error message properly at
      # the moment
      console.log '$.ajax error:', e
      status = e.statusCode # TODO: is this right?
      return error {status}, status, e.message
    # should be enough???
    req.setTimeout 300000

    if type is 'POST'
      req.write data
    req.end()
    fake_xhr =
      abort: ->
        aborted = true
        req.abort()
        return error {
          status: '???whatshouldthisbe???'
        }, 0, "ABORTED"
    return fake_xhr
