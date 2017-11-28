{$ajax} = require 'client/lib/http_util.iced'

class LoginContainer
  # temporary warning
  SIGNUP_WARNING = '''
    <div class="temporary-warning">
      <font color="red">Warning:</font> This project
      is still in the early stages of development and
      has not undergone a rigorous security review.
      We therefore strongly discourage using any
      potentially sensitive passwords for this site.
    </div>
  '''
  TMPL = '''
  <div class="login-container">
    <div class="login-header">
      <div class="current-widget"></div>
      <a href="#" class="switch-widget"></a>
    </div>
    <div class="login-widget"></div>
  </div>
  '''

  constructor: ->
    @_warning = $ SIGNUP_WARNING
    @_warning.hide()
    @_warning.prependTo ($ document.body)

    @_elt = $ TMPL
    @_container = @_elt.find 'div.login-widget'
    (@_elt.find '.switch-widget').click =>
      @_on_switch()
    @_on_switch = ->

  elt: -> @_elt

  set_widget: (widget_type) ->
    @_container.empty()
    switch_link = @_elt.find '.switch-widget'

    switch widget_type
      when 'login'
        @_container.append (new LoginWidget).elt()
        (@_elt.find 'div.current-widget').text "Login"
        switch_link.text "Sign up"
        @_on_switch = =>
          @set_widget 'signup'
        @_warning.hide()

      when 'signup'
        @_container.append (new SignupWidget).elt()
        (@_elt.find 'div.current-widget').text "Sign up"
        switch_link.text "Login"
        @_on_switch = =>
          @set_widget 'login'
        @_warning.show()

      else
        throw new Error "invalid widget type #{widget_type}"


class SignupWidget
  DEFAULT_NEXT = window.TEMPLATE_PARAMS.next_url
  WIDGET_TMPL = '''
    <div>
      <div class="tr-div">
        <div class="tc-div">Name</div>
        <input placeholder="First" class="signup-input first-name-input" type="text"></input>
        <input placeholder="Last" class="signup-input last-name-input" type="text"></input>
      </div>
      <div class="tr-div">
        <div class="tc-div">Username</div>
        <input class="signup-input username-input" type="text"></input>
      </div>
      <div class="tr-div">
        <div class="tc-div">Password</div>
        <input class="signup-input password-input" type="text"></input>
      </div>
      <button class="standard-button sign-up-button">Sign up!</button>
      <div class="status-area"></div>
    </div>
  '''

  constructor: (defaults = {}, @next = DEFAULT_NEXT) ->
    @_elt = $ WIDGET_TMPL
    (@_elt.find 'button.sign-up-button').click (@do_signup.bind @)
    (@_elt.find 'form.login-form').css display: 'inline'

    if defaults.username?
      (@_elt.find 'input.username-input').val defaults.username
    if defaults.password?
      (@_elt.find 'input.password-input').val defaults.password
    @_status_area = @_elt.find 'div.status-area'

  elt: ->
    return @_elt

  set_status: (text) ->
    @_status_area.stop true
    @_status_area.css {
      opacity: 1
    }
    @_status_area.text text
    @_status_area.animate {
      opacity: 1
    }, 200
    @_status_area.animate {
      opacity: 0.5
    }, 1000

  do_signup: ->
    first_name = @_elt.find('input.first-name-input').val()
    last_name = @_elt.find('input.last-name-input').val()

    username = @_elt.find('input.username-input').val()
    password = @_elt.find('input.password-input').val()

    # TODO: better error messages
    if first_name == '' or last_name == ''
      return @set_status "Invalid first or last name."
    if username == '' or password == ''
      return @set_status "Invalid username or password."

    data =
      username: username
      password: password
      signup: true
      info:
        first_name: first_name
        last_name: last_name

    $ajax '/login', data, 'post', (err, res) =>
      if err
        return @set_status (JSON.stringify err)
      if not res.success
        return @set_status res.reason
      window.location.href = @next


class LoginWidget
  DEFAULT_NEXT = window.TEMPLATE_PARAMS.next_url
  WIDGET_TMPL = '''
  <div class="table-div">
    <div class="tr-div">
      <div class="tc-div">Username</div>
      <input class="username-input login-input" type="text"></input>
    </div>
    <div class="tr-div">
      <div class="tc-div">Password</div>
      <input class="password-input login-input" type="password"></input>
    </div>
    <button class="standard-button login-button">Login</button>
    <div class="status-area"></div>
  </div>
  '''

  constructor: (@next = DEFAULT_NEXT) ->
    @_elt = $ WIDGET_TMPL
    @_username_input = @_elt.find 'input.username-input'
    @_password_input = @_elt.find 'input.password-input'
    @_status_area = @_elt.find 'div.status-area'

    (@_elt.find 'button.login-button').click (@do_login.bind @)
    (@_elt.find 'form.login-form').css display: 'inline'

  elt: ->
    return @_elt

  get_values: ->
    ret =
      username: @_username_input.val()
      password: @_password_input.val()
    return ret

  set_status: (text) ->
    @_status_area.stop true
    @_status_area.css {
      opacity: 1
    }
    @_status_area.text text
    @_status_area.animate {
      opacity: 1
    }, 200
    @_status_area.animate {
      opacity: 0.5
    }, 1000

  do_login: ->
    data = @get_values()
    $ajax.post '/login', data, (err, res) =>
      if err
        return @set_status (JSON.stringify err)
      if not res.success
        return @set_status "The username or password is incorrect."
      window.location.href = @next

window.onload = ->
  container = new LoginContainer()
  ($ document.body).append container.elt()
  container.set_widget 'login'

