assert = require 'assert'
Client = require 'game_engine/client/setup.iced'
util_m = require 'shared/util.iced'
{T} = require 'shared/T/T.iced'
{R} = require 'client/lib/R.iced'

{TextBox, Button} = require 'canvas/window.iced'
{BorderFrame, Frame, HBox, VBox} = require 'canvas/container.iced'

{GridDisplay, ListDisplay} = require 'games/battleship/grid_display.iced'
canvas_util_m = require 'canvas/canvas_util.iced'
Graphics = require 'games/battleship/graphics.iced'


class PlaceController
  constructor: (@gc, @player_id, @shared) ->
    @_grid = @_ships = null
    @_horiz = true

  # TODO: temporary hack
  _ship_placement: (ship_num) ->
    placements = @gc.state().players[@player_id].placements
    for r in [0...8]
      for c in [0...8]
        if (placements.get r, c) is ship_num
          horiz = ((placements.get r, (c+1)) is ship_num)
          return {r, c, horiz}
    return null

  _make_grid: ->
    me = @gc.state().players[@player_id]
    grid = Graphics.large.make_grid()
    ships_layer = Graphics.large.ships_layer @gc, @player_id, (ship_num) =>
      return (ship_num is @_ships.selection()[0])
    grid.add_custom_layer ships_layer
    grid.add_hover_layer()

    grid.on_click (r, c, right) =>
      if right
        @_horiz = not @_horiz
        grid.set_hover_behavior @ship_hover()
        return

      [ship_num, ship] = @_ships.selection()
      if ship_num?
        # TODO: their "vertical" is actually horizontal b/c of
        # row/column switch
        await @gc.submit_action 'place', [ship_num, r, c, @_horiz],
          defer res, err
        @_horiz = true
    return grid

  ship_hover: ->
    [ship_num, ship] = @_ships.selection()
    if not ship_num? then return null
    return {
      cols: (if @_horiz then ship.length else 1)
      rows: (if @_horiz then 1 else ship.length)
      draw: (ctx, r, c) =>
        transparent = not (@gc.is_valid 'place', [ship_num, r, c, @_horiz])
        Graphics.large.draw_ship ctx, ship, @_horiz, transparent
    }

  update: ->
    me = @gc.state().players[@player_id]
    @_grid = @_make_grid()
    @_ships = new ListDisplay me.ships, {
      item_width: 210, item_height: 50
      draw: (ctx, ship) => # TODO
        ctx.drawImage (R.get_img "ship#{ship.length}"),
          5, 5
    }
    @_ships.on_sel_change =>
      @_grid.set_hover_behavior @ship_hover()

    done_button = if @gc.state().is_done[@player_id]
      new Button {
        width: 200, height: 40
        size: 12, text: "Waiting for opponent..."
      }
    else
      new Button {
        text: "Done", size: 20, width: 200, height: 40
        handler: =>
          await @gc.submit_action 'done', [], defer err, res
      }
    if not (@gc.is_valid 'done', [])
      done_button.disable()

    @shared.root.set_child 'center', @_grid
    @shared.root.set_child 'right', (new VBox {
      spacing: 40
    }, [
      new TextBox {text: "Place your ships!", size: 20}
      @_ships, done_button
    ])

  init: ->
    @update()

  action: (data) ->
    @update()

  cleanup: ->
    @shared.root.set_child 'center', null
    @shared.root.set_child 'right', null


class GuessController
  constructor: (@gc, @player_id, @shared) ->
    @_my_grid = null
    @_opp_grid = null

  _me: -> @gc.state().players[@player_id]
  _opponent: -> @gc.state().players[1 - @player_id]

  update: ->
    @_my_grid = Graphics.small.make_grid()
    @_my_grid.add_custom_layer (Graphics.small.ships_layer @gc, @player_id)
    @_my_grid.add_tile_layer (ctx, r, c) =>
      guess = @_opponent().guesses.get(r, c)
      Graphics.small.draw_guess ctx, guess

    @_opp_grid = Graphics.small.make_grid()
    @_opp_grid.add_tile_layer (ctx, r, c) =>
      guess = @_me().guesses.get(r, c)
      Graphics.small.draw_guess ctx, guess

    @_opp_grid.on_click (r, c, right) =>
      if right then return
      await @gc.submit_action 'guess', [r, c],
        defer res, err

    my_turn = @gc.state().cur_turn is @player_id
    @shared.root.set_child 'top', (new TextBox {
      text: (if my_turn then "Your turn!" else "Opponent's turn")
      size: 20
    })

    @shared.root.set_child 'center', (Graphics.two_grids @_my_grid, @_opp_grid)

  init: ->
    @update()

  action: (data) ->
    @update()

  cleanup: ->
    @shared.root.set_child 'top', null
    @shared.root.set_child 'center', null


class GameOverController
  constructor: (@gc, @player_id, @shared) ->
    @_my_grid = null
    @_opp_grid = null

  _me: -> @gc.state().players[@player_id]
  _opponent: -> @gc.state().players[1 - @player_id]

  update: ->
    @_my_grid = Graphics.small.make_grid()
    @_my_grid.add_custom_layer (Graphics.small.ships_layer @gc, @player_id)
    @_my_grid.add_tile_layer (ctx, r, c) =>
      guess = @_opponent().guesses.get(r, c)
      Graphics.small.draw_guess ctx, guess

    @_opp_grid = Graphics.small.make_grid()
    @_opp_grid.add_custom_layer (Graphics.small.ships_layer @gc, (1 - @player_id))
    @_opp_grid.add_tile_layer (ctx, r, c) =>
      guess = @_me().guesses.get(r, c)
      Graphics.small.draw_guess ctx, guess

    # TODO: show who won
    @shared.root.set_child 'top', (new TextBox {
      text: 'Game Over'
      size: 20
    })
    @shared.root.set_child 'center', (Graphics.two_grids @_my_grid, @_opp_grid)

  init: ->
    @update()

  action: (data) ->
    @update()

  cleanup: -> # TODO: not really needed for game over


RESOURCES = []
for name, idx in ['sub', 'destroyer', 'battleship', 'carrier']
  RESOURCES.push (R.Image "ship#{idx+2}", {
    url: "/games/battleship/resources/#{name}.png",
    width: 40*(idx + 2), height: 40
  })

Client.setup {
  resources: RESOURCES
  background: Graphics.SAND
  dims: {width: 800, height: 600}
  game_spec: window.ALL_GAMES.battleship
  make_mode_handlers: (canv_root, gc, player_id) ->
    margin = 20
    shared =
      root: new BorderFrame {
        forced_dims:
          width: canv_root.width - 2 * margin
          height: canv_root.height - 2 * margin
      }
    canv_root.add shared.root, margin, margin
    return {
      Place: (new PlaceController gc, player_id, shared)
      Guess: (new GuessController gc, player_id, shared)
      GameOver: (new GameOverController gc, player_id, shared)
    }
}