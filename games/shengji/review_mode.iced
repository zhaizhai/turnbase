{Button, TextBox} = require 'canvas/window.iced'
{HBox, VBox, BorderFrame} = require 'canvas/container.iced'


{CardGraphics} = require 'canvas/card_graphics.iced'
{CardHand} = require 'canvas/card_hand.iced'


class ReviewController
  constructor: (@gc, @player_id, @shared) ->
  _make_center_elt: ->
    ch = new CardHand CardGraphics
    ch.set_hand @gc.game().buried

    pt = @gc.game().points_team
    p1 = @gc.username_for_player pt
    p2 = @gc.username_for_player ((pt + 2) % 4)
    return new VBox {}, [
      ch,
      new TextBox {
        text: "#{p1} / #{p2} got #{@gc.game().points_taken} points!"
      }
    ]

  update: ->
    @shared.scoreboard.update()

    ch = new CardHand CardGraphics
    ch.set_hand @gc.game().buried
    @shared.root.set_child 'center', @_make_center_elt()

    @_status_elts = [null, null, null, null]

    @_status_elts[@player_id] = if @gc.game().ready[@player_id]
      new TextBox {
        text: 'Ready'
      }
    else
      new Button {
        text: 'Next round'
        handler: =>
          await @gc.submit_action {
            cmd: 'continue', info: []
          }, defer err, res
          throw err if err
      }

    for idx in [1..3]
      pid = (@player_id + idx) % 4
      status = if @gc.game().ready[pid]
        'Ready'
      else
        "Waiting for #{@gc.username_for_player pid}..."
      @_status_elts[pid] = new TextBox {
        text: status
      }

    for pos, idx in ['bottom', 'left', 'top', 'right']
      elt = @_status_elts[(@player_id + idx) % 4]
      if idx % 2 == 0 # bottom and top
        [w, h] = [100, 100]
      else
        [w, h] = [200, 100]
      @shared.root.set_child pos,  new BorderFrame {
        forced_dims: {width: w, height: h}
        center: elt
      }

  init: ->
    @update()

  action: (data) ->
    @update()

  cleanup: ->
    for pos in ['left', 'right', 'top', 'bottom', 'center']
      @shared.root.set_child pos, null

exports.ReviewController = ReviewController