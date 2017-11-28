assert = require 'assert'
{GameClient} = require 'game_engine/client/game_client.iced'
{OpStream} = require 'game_engine/client/op_stream.iced'

{R} = require 'client/lib/R.iced'
{$ajax} = require 'client/lib/http_util.iced'
{LongPollClient} = require 'client/lib/poll_client.iced'
{ChatClient} = require 'client/chat.iced'
{PlayersList} = require 'client/players.iced'
{TableInfo} = require 'client/table_info.iced'

measure_m = require 'canvas/measure.iced'
{BufferedCanvas} = require 'canvas/canvas_util.iced'
window_m = require 'canvas/window.iced'
{Button} = window_m
{Frame} = require 'canvas/container.iced'
{CanvasDebugger} = require 'canvas/debug.iced'

class DefaultMainController
  constructor: (@gc, @root) ->
    onclick = =>
      await @gc.submit_action 'start', [], defer err, res
      console.log "returned from start", err, res

    @_start_button = new Button {
      width: 100, height: 60,
      text: 'Start', handler: onclick
    }
    @_old_children = []

  init: ->
    @_old_children = @root.children.slice()
    @root.children = []

    x = (@root.width - @_start_button.width) / 2
    y = (@root.height - @_start_button.height) / 2
    @root.add_child @_start_button, x, y
  action: (data) ->
  cleanup: ->
    @root.remove_child @_start_button
    for child_info in @_old_children
      @root.add_child child_info.elt,
        child_info.x, child_info.y

create_canvas = (params) ->
  if params.client_type is 'mobile'
    # TODO: Eventually, we'd like to use the the HTML5 fullscreen
    # API. Unfortunately, it is not currently supported by most
    # mobile browsers.
    [w, h] = [400, 400 * screen.height / screen.width - 120]
    canv = new BufferedCanvas w, (h + 1)
    canv.elt().css({position: 'absolute', top: 0, left: 0})

  else
    [w, h] = [params.dims.width, params.dims.height]
    canv = new BufferedCanvas w, h

  ($ '#game-region').append canv.elt()
  measure_m.set_ctx canv.ctx()
  if params.client_type is 'party'
    game_elt = $('#game-container')
    game_elt.click =>
      for func in ['requestFullscreen', 'mozRequestFullScreen',
                   'webkitRequestFullscreen', 'msRequestFullscreen']
        if game_elt.get(0)[func]?
          game_elt.get(0)[func]()
          break
  return canv

setup = (params) ->
  REQUIRED_PARAMS = [
    'game_spec', 'make_mode_handlers'
  ]
  for req in REQUIRED_PARAMS
    if not params[req]?
      throw new Error "Missing param #{req}"
  DEFAULT_PARAMS =
    resources: [], fps: 50, client_type: 'web'
    onerror: (err) ->
      console.error 'Could not set up game:', err
      throw err
    background: '#dddddd'
  for k, v of DEFAULT_PARAMS
    params[k] ?= v
  assert (params.client_type is 'mobile') or params.dims?

  window.onload = ->
    {tid, player_id, game_type} = TEMPLATE_PARAMS

    await R.init params.resources, defer err
    if err then return params.onerror err

    canv = create_canvas params
    outer_root = new Frame {
      width: canv.width, height: canv.height
      background: params.background
    }

    lpc = new LongPollClient "/table/#{tid}/poll"
    op_stream = new OpStream lpc

    table_info = new TableInfo tid, player_id, lpc
    players_list = new PlayersList table_info, params.game_spec.has_bots
    ($ '#right-column').append players_list.elt()

    chat_client = new ChatClient lpc, player_id,
      "/table/#{tid}/chat", "#{tid}:chat"
    ($ '#right-column').append chat_client.elt()

    window.gc = gc = new GameClient params.game_spec,
      table_info, player_id, op_stream
    gc.on 'log-mesg', (mesg) ->
      chat_client.add_message mesg, 'bold'

    start_gc = (cb) ->
      # clear old UI
      outer_root.children = []
      outer_root.layout()

      mh = params.make_mode_handlers outer_root,
        gc, player_id
      mh.Main ?= new DefaultMainController gc, outer_root
      # TODO: validate mh
      await gc.init mh, defer err
      if err then return params.onerror err
      return cb()

    table_info.on 'new-game', ->
      # TODO: actually, we need to make sure the client is ready for
      # the new game (e.g. not still doing an animation)
      await start_gc defer()

    await start_gc defer()
    lpc.run()

    # for debugging
    cdb = new CanvasDebugger canv
    window.DEBUG =
      buffered_canvas: canv
      debug_canvas: ->
        cdb.debug outer_root
      canvas_root: outer_root

    window_m.render_loop canv, outer_root, params.fps


exports.DefaultMainController = DefaultMainController
exports.R = R
exports.setup = setup
