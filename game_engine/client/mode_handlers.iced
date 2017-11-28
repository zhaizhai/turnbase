# TODO: not used yet

window_m = require 'canvas/window.iced'
{Button} = window_m

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

class ModeHandler
  constructor: ->

  init: ->

  action: (data) ->

  cleanup: ->