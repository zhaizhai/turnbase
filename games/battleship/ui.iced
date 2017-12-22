assert = require 'assert'
Client = require 'game_engine/client/setup.iced'
util_m = require 'shared/util.iced'
{T} = require 'shared/T/T.iced'
{R} = require 'client/lib/R.iced'

{TextBox, Button} = require 'canvas/window.iced'
{BorderFrame, Frame, HBox, VBox} = require 'canvas/container.iced'

{ListDisplay} = require 'canvas/list_display.iced'
{GridDisplay} = require 'canvas/grid_display.iced'
canvas_util_m = require 'canvas/canvas_util.iced'
Graphics = require 'games/battleship/graphics.iced'

class PlaceHandler
  constructor: (@gc, @player_id, @root) ->
    @_grid = @_ships = null
    @_horiz = true

  ship_hover: ->
    sel = @_ships.selection()
    [ship, ship_num] = [sel.item, sel.index]
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
    @_grid = Graphics.large.make_grid()
    ships_layer = Graphics.large.ships_layer @gc, @player_id, (ship_num) =>
      return (ship_num is @_ships.selection().index)
    @_grid.add_custom_layer ships_layer
    @_grid.add_hover_layer()
    @_grid.on_click (r, c, right) =>
      if right
        @_horiz = not @_horiz
        @_grid.set_hover_layer @ship_hover()
        return
      ship_num = @_ships.selection().index
      if ship_num?
        # TODO: their "vertical" is actually horizontal b/c of
        # row/column switch
        @gc.submit_action 'place', [ship_num, r, c, @_horiz]
        @_horiz = true

    @_ships = new ListDisplay me.ships, {
      item_width: 210, item_height: 50
      draw: (ctx, ship) =>
        ctx.drawImage (R.get_img "ship#{ship.length}"), 5, 5
    }
    @_ships.on_change =>
      @_grid.set_hover_layer @ship_hover()

    done_button = if @gc.state().is_done[@player_id]
      new Button {
        text: "Waiting for opponent...", size: 12, width: 200, height: 40
      }
    else
      new Button {
        text: "Done", size: 20, width: 200, height: 40
        handler: => @gc.submit_action 'done', []
      }
    if not (@gc.is_valid 'done', [])
      done_button.disable()

    @root.set_child 'center', @_grid
    @root.set_child 'right', (new VBox { spacing: 40 }, [
      new TextBox {text: "Place your ships!", size: 20}
      @_ships, done_button
    ])

  cleanup: ->
    @root.set_child 'center', null
    @root.set_child 'right', null

class GuessHandler
  constructor: (@gc, @player_id, @root) ->

  update: ->
    my_grid = Graphics.small.make_guesses_grid @gc, @player_id
    opp_grid = Graphics.small.make_guesses_grid @gc, (1 - @player_id)
    opp_grid.on_click (r, c, right) =>
      if right then return
      @gc.submit_action 'guess', [r, c]

    my_turn = @gc.state().cur_turn is @player_id
    @root.set_child 'top', (new TextBox {
      text: (if my_turn then "Your turn!" else "Opponent's turn")
      size: 20
    })
    @root.set_child 'center', (Graphics.two_grids my_grid, opp_grid)

  cleanup: ->
    @root.set_child 'top', null
    @root.set_child 'center', null

class GameOverHandler
  constructor: (@gc, @player_id, @root) ->

  update: ->
    my_grid = Graphics.small.make_guesses_grid @gc, @player_id
    opp_grid = Graphics.small.make_guesses_grid @gc, (1 - @player_id)
    # TODO: show who won
    @root.set_child 'top', (new TextBox {text: 'Game Over', size: 20})
    @root.set_child 'center', (Graphics.two_grids my_grid, opp_grid)

  cleanup: ->

Client.setup {
  resources: Graphics.SHIP_IMAGES
  background: Graphics.SAND
  dims: {width: 800, height: 600}
  game_spec: window.ALL_GAMES.battleship
  make_mode_handlers: (canv_root, game_client, player_id) ->
    margin = 20
    root = new BorderFrame {
      forced_dims:
        width: canv_root.width - 2 * margin
        height: canv_root.height - 2 * margin
    }
    canv_root.add root, margin, margin
    return {
      Place: (new PlaceHandler game_client, player_id, root)
      Guess: (new GuessHandler game_client, player_id, root)
      GameOver: (new GameOverHandler game_client, player_id, root)
    }
}