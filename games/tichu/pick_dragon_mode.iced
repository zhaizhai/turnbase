window_m = require 'canvas/window.iced'
{Button, TextInfo} = window_m
container_m = require 'canvas/container.iced'
{BorderFrame, HBox, VBox} = container_m

{PointsDisplay} = require 'games/tichu/points_display.iced'

class PickDragonController
  constructor: (@gc, @player_id, @root, @shared) ->
    @points_display = new PointsDisplay @gc, @player_id, {
      width: 80, size: 16, num_rows: 4
    }

  init: ->
    @points_display.update()

    if @player_id isnt @gc.state().dragon_picker
      @shared.ui.init {display_pts: true, ctrls: @points_display.elt()}
      @shared.ui.update()
      return

    @shared.ui.init {display_pts: true}
    @shared.ui.update()

    # TODO: temporary hack of replacing bottom component entirely
    ch = @shared.ui.card_hand()
    pass_left = new Button {
      text: 'Pass left'
      handler: =>
        await @gc.submit_action 'pick', [1], defer err, res
        throw err if err
    }
    pass_right = new Button {
      text: 'Pass right'
      handler: =>
        await @gc.submit_action 'pick', [3], defer err, res
        throw err if err
    }

    @root.set_child 'bottom', new HBox {spacing: 10}, [
      pass_left, ch, pass_right, @points_display.elt()
    ]

  cleanup: ->
    @shared.ui.cleanup()

  action: (data) ->

exports.PickDragonController = PickDragonController
