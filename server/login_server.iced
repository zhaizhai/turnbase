mustache_m = require 'mustache'
{V} = require 'shared/T/validation.iced'
{AppRouter} = require 'server/server_util.iced'
{User, UserStore} = require 'server/user.iced'

templates_m = require 'server/templates.iced'
{render_template} = templates_m

class LoginServer
  constructor: (@user_store) ->
    @_ar = new AppRouter
    @_set_routes()

  get_app_router: -> @_ar

  login_first: (req, res) ->
    orig_url = req.url
    if orig_url is '/'
      return res.redirect "/login"
    return res.redirect "/login?next_url=#{orig_url}"

  _set_routes: ->
    @_ar.get '/logout', {
    }, (req, res) ->
      delete req.session.uid
      res.clearCookie 'uid'
      return (res.redirect '/')

    @_ar.get '/login', {
      query:
        next_url: (V.Nullable V.String)
    }, (req, res) ->
      {next_url} = req.args
      # TODO: ensure redirect is to own domain
      next_url ?= '/'

      await render_template 'templates/login.mustache', {
        js_deps: ['&jquery', 'lib/http_util.iced', 'login.iced']
        js_params: (JSON.stringify {next_url})
      }, defer err, rendered_tmpl

      # TODO: more graceful error handling
      return (res.send err) if err
      return (res.send rendered_tmpl)

    @_ar.post '/login', {
      body:
        username: V.String
        password: V.String
        info: V.Object # TODO: more validation
        signup: (V.Nullable V.Boolean)
    }, (req, res) =>
      {username, password, info, signup,
       next_url} = req.args
      console.log 'Login attempt from', username
      password_hash = UserStore.hash_password password
      user = null

      if signup
        if not UserStore.is_valid_username username
          return res.send {
            success: false
            reason: "The username is invalid."
          }

        await @user_store.make_user username,
          password_hash, info, defer err, user
        if err
          if err.code is 'USER_EXISTS'
            return res.send {
              success: false
              reason: "The username is already taken."
            }
          return res.status(400).send(err)
        req.session.uid = user.uid
        return res.send {success: true, uid: user.uid}

      else
        await @user_store.authorize username,
          password_hash, defer err, user
        return res.status(400).send(err) if err
        if not user?
          return res.send {success: false}

        req.session.uid = user.uid
        res.cookie 'uid', user.uid, {signed: true}
        return res.send {success: true, uid: user.uid}


exports.LoginServer = LoginServer