Client = require 'game_engine/client/setup.iced'
window_m = require 'canvas/window.iced'
{Button, TextBox, InvisibleBox} = window_m
{BorderFrame, HBox, VBox} = require 'canvas/container.iced'
{Table} = require 'canvas/table.iced'

# TODO: simplify UI implementation and add more detailed explanation
class PlayController
  text_from_val = (val) ->
    if not val? then return '__'
    return if (val == 0) then 'X' else 'O'

  constructor: (@gc, @player_id, @shared) ->

  _mesg_text: ->
    cur_turn = @gc.state().cur_turn
    if @player_id is cur_turn
      return "Your move."
    return "#{(@gc.username_for_player cur_turn)}'s move."

  update: ->
    @shared.root.set_child 'top', (new VBox {}, [
      (new InvisibleBox 0, 120)
      new TextBox {
        size: 28, align: 'center', text: @_mesg_text()
      }
    ])

    grid = new Table 3, 3, { padding: 12 }
    for i in [0...3]
      for j in [0...3]
        do (i, j) =>
          val = @gc.state().grid.get(i, j)
          text = text_from_val val
          button = new Button {
            width: 80, height: 80, text: text, size: 40
            handler: =>
              @gc.submit_action 'play', [i, j], (err, res) ->
                console.log err, res
          }
          if val?
            button.disable()
          grid.set_cell(i, j, button)
    @shared.root.set_child 'center', grid
    @shared.canv_root.add @shared.root, 0, 0

  init: ->
    @update()

  action: (data) ->
    @update()

  cleanup: ->
    @shared.root.set_child 'center', null


Client.setup {
  background: '#aaaadd'
  dims:
    width: 600
    height: 600
  game_spec: window.ALL_GAMES.tictactoe
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
   }
}