assert = require 'assert'
util_m = require 'shared/util.iced'
{R} = require 'client/lib/R.iced'

{TextBox, Button} = require 'canvas/window.iced'
{BorderFrame, Frame, HBox, VBox} = require 'canvas/container.iced'
{GridDisplay} = require 'games/battleship/grid_display.iced'

exports.SEA_BLUE = SEA_BLUE = '#5566ff'
exports.SAND = SAND = '#f7f3b2'

class BattleshipGraphics
  constructor: (@cell_size) ->

  draw_guess: (ctx, guess) ->
    if guess is "hit"
      ctx.fillStyle = 'red'
      ctx.fillRect 5, 5, (@cell_size - 10), (@cell_size - 10)
    else if guess is "miss"
      ctx.fillStyle = 'white'
      ctx.fillRect 5, 5, (@cell_size - 10), (@cell_size - 10)

  draw_ship: (ctx, ship, horiz, transparent = false) ->
    # TODO: only draws one size
    ship_img = R.get_img "ship#{ship.length}"
    ctx.save()
    if transparent then ctx.globalAlpha = 0.4
    if not horiz
      ctx.transform(0, -1, 1, 0, 0, (ship.length * @cell_size))
    ctx.drawImage ship_img, 0, 0, (ship.length * @cell_size), @cell_size
    ctx.restore()

  make_grid: ->
    return new GridDisplay {
      background: SEA_BLUE, rows: 8, cols: 8
      size: @cell_size, margin: Math.floor(@cell_size / 4)
    }

  ships_layer: (gc, player_id, is_transparent) ->
    is_transparent ?= (ship_num) -> false
    draw = (ctx) =>
      player = gc.state().players[player_id]
      drawn = (false for _ in player.ships)
      placements = player.placements
      # TODO: temporary hack
      for r in [0...8]
        for c in [0...8]
          s = placements.get r, c
          if (not s?) or drawn[s] then continue

          [x, y] = [c * @cell_size, r * @cell_size]
          horiz = ((placements.get r, (c+1)) is s)
          transparent = is_transparent s

          ctx.translate x, y
          @draw_ship ctx, player.ships[s], horiz, transparent
          ctx.translate -x, -y
          drawn[s] = true
    return {draw}

exports.small = new BattleshipGraphics 40
exports.large = new BattleshipGraphics 60
exports.two_grids = (my_grid, opp_grid) ->
  return new HBox {
    spacing: 40
  }, [
    new VBox {}, [my_grid, new TextBox {
      size: 20, text: "Your ships"
    }]
    new VBox {}, [opp_grid, new TextBox {
      size: 20, text: "Opponent's ships"
    }]
  ]
