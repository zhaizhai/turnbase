Client = require 'game_engine/client/setup.iced'
window_m = require 'canvas/window.iced'
{Button} = window_m
{BorderFrame, HBox, VBox} = require 'canvas/container.iced'

class PlayController
  constructor: (@gc, @player_id, @shared) ->

  update: ->
    grid = new VBox {}
    for i in [0...3]
      row = new HBox {}
      for j in [0...3]
        do (i, j) =>
          val = @gc.state().grid.get(i, j)
          text = if val? then ('' + val) else '_'
          button = new Button {
            width: 40, height: 40, text: text
            handler: =>
              @gc.submit_action 'play', [i, j], (err, res) ->
                console.log err, res
          }
          if val?
            button.disable()
          row.add button
      grid.add row

    @shared.root.set_child 'center', grid
    @shared.canv_root.add @shared.root, 0, 0

  init: ->
    console.log 'Enter play mode'
    @update()

  action: (data) ->
    @update()

  cleanup: ->
    @shared.root.set_child 'center', null


Client.setup {
  background: '#aaaadd'
  dims:
    width: 800
    height: 600
  game_spec: window.ALL_GAMES.tictactoe
  #game_module: (require 'games/tictactoe/tictactoe.iced')
  make_mode_handlers: (canv_root, gc, player_id) ->
    shared =
      root: new BorderFrame {
        forced_dims:
          width: canv_root.width
          height: canv_root.height
      }
      canv_root: canv_root
    return {
      Main: (new Client.DefaultMainController gc, canv_root)
      Play: (new PlayController gc, player_id, shared)
      #GameOver: (new GameOverController gc, shared)
    }
}