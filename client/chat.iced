{$ajax} = require 'client/lib/http_util.iced'
html_util_m = require 'client/lib/html_util.iced'

class ChatClient
  CHAT_TMPL = '''
  <div class="chat-container">
    <div class="region-header">Chat</div>
    <div class="chat-region"></div>
    <input class="chat-input"></input>
  </div>
  '''

  # TODO: typecheck these
  constructor: (@lpc, @cid, @endpoint, @channel) ->
    @_elt = $ CHAT_TMPL
    @_init()

  elt: -> @_elt

  add_message: (mesg, style = null) ->
    text_elt = ($ "<div>#{mesg}</div>")
    if style is 'bold'
      text_elt.css 'font-weight', 'bold'

    chat_region = @_elt.find '.chat-region'

    # TODO: this doesn't account for possible horizontal scrollbar; we
    # can use chat_region[0].clientHeight instead of
    # chat_region.height() in that case, but I'm not sure about
    # x-browser compatibility
    hidden_height = chat_region[0].scrollHeight - chat_region.height()
    scrolled = chat_region.scrollTop() isnt hidden_height

    old_height = chat_region.height()
    chat_region.append text_elt
    # TODO: Hack to prevent chat element from growing larger. There
    # should be a way with CSS but I don't know how.
    if old_height > 0
      # Hack to not set max-height to 0 in case element hasn't
      # rendered yet.
      chat_region.css 'max-height', old_height

    if not scrolled
      hidden_height = chat_region[0].scrollHeight - chat_region.height()
      chat_region.scrollTop hidden_height

  _make_mesg: (username, ts, mesg) ->
    now = new Date ts
    time_str = now.toTimeString().split(' ')[0]
    return "<b>[#{time_str}] #{username}:</b> #{mesg}"

  _init: ->
    @lpc.register_handler @channel, @cid, 0, (data_list) =>
      for data in data_list
        {username, mesg, timestamp} = data
        disp_mesg = @_make_mesg username, timestamp, mesg
        @add_message disp_mesg

    input_elt = (@_elt.find 'input.chat-input')
    input_elt.keydown (e) =>
      # console.log 'keydown', e.which
      if e.which isnt 13 # enter key
        return

      mesg = input_elt.val()
      input_elt.val ''
      await $ajax.post @endpoint, {mesg},
        defer err, res
      if err
        console.log 'chat error', err
        # input_elt.val mesg

exports.ChatClient = ChatClient
