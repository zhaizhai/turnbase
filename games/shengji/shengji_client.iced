assert = require 'assert'

shengji_m = require 'games/shengji/shengji.iced'
{
  setup_game, DefaultMainController, R
} = require 'game_spec/client/client_setup.iced'

window_m = require 'canvas/window.iced'
{Button} = window_m
{BorderFrame} = require 'canvas/container.iced'
{BufferedCanvas} = require 'canvas/canvas_util.iced'

{CardGraphics} = require 'canvas/card_graphics.iced'
{CardHand} = require 'canvas/card_hand.iced'

{ScoreBoard} = require 'games/shengji/shared_ui.iced'
{DrawController} = require 'games/shengji/draw_mode.iced'
{BuryController} = require 'games/shengji/bury_mode.iced'
{PlayController} = require 'games/shengji/play_mode.iced'
{ReviewController} = require 'games/shengji/review_mode.iced'

setup_game {
  resources: [
    R.Image 'card-set', {
      url: '/games/shengji/classic-cards.png'
      width: 934
      height: 390
    }
  ]
  background: '#008000'
  dims:
    width: 800
    height: 600
  game_module: (require 'games/shengji/shengji.iced')
  make_mode_handlers: (canv_root, gc, player_id) ->
    shared =
      root: new BorderFrame {
        forced_dims:
          width: canv_root.width
          height: canv_root.height
      }
      canv_root: canv_root
      scoreboard: new ScoreBoard gc
    ($ '#right-column').prepend shared.scoreboard.elt()

    canv_root.add_child shared.root, 0, 0
    return {
      Main: (new DefaultMainController gc, canv_root)
      Draw: (new DrawController gc, player_id, shared)
      Bury: (new BuryController gc, player_id, shared)
      Play: (new PlayController gc, player_id, shared)
      Review: (new ReviewController gc, player_id, shared)
    }
}
