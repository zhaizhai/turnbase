assert = require 'assert'
mustache_m = require 'mustache'

{R} = require 'client/lib/R.iced'
Client = require 'game_engine/client/setup.iced'

window_m = require 'canvas/window.iced'
{Button} = window_m
{BorderFrame, Frame} = require 'canvas/container.iced'
{BufferedCanvas} = require 'canvas/canvas_util.iced'

{SharedUI} = require 'games/tichu/ui_helpers.iced'
{PassController} = require 'games/tichu/pass_mode.iced'
{PlayController} = require 'games/tichu/play_mode.iced'
{PickDragonController} = require 'games/tichu/pick_dragon_mode.iced'
{GrandTichuController} = require 'games/tichu/grand_tichu_mode.iced'


class ScoreBoard
  render_to_jquery = (tmpl, params) ->
    html = mustache_m.to_html tmpl, params
    return $ html
  SCOREBOARD_TMPL = '''
  <table class="scoreboard">
    <tr>
      <td>{{team1}}</td><td>{{team2}}</td>
    </tr>
  </table>
  '''
  ROW_TMPL = '''
  <tr>
    <td>{{score1}}</td>
    <td>{{score2}}</td>
  </tr>
  '''

  constructor: (@gc) ->
    @_elt = render_to_jquery SCOREBOARD_TMPL, {
      team1: 'Team 1'
      team2: 'Team 2'
    }
    @_rows = []

  elt: -> @_elt

  update_score: ->
    for row in @_rows
      row.remove()

    score1 = score2 = 0
    for scores in [[0, 0]].concat(@gc.state().team_points)
      score1 += scores[0]
      score2 += scores[1]
      row = render_to_jquery ROW_TMPL, {score1, score2}
      @_elt.append row
      @_rows.push row


class MainController
  constructor: (@gc, @root, @shared) ->
    onclick = =>
      await @gc.submit_action 'start', [], defer err, res
      console.log "returned from player #{@player_id} start", err, res

    @_start_button = new Button {
      width: 100, height: 60,
      text: 'Start', handler: onclick
    }

  init: ->
    @root.set_child 'center', @_start_button
  action: (data) ->
  cleanup: ->
    @root.set_child 'center', null


Client.setup {
  resources: [R.Image 'tichu-cards', {
    url: "/games/tichu/resources/tichu.png"
    width: 1170, height: 630
  }]
  background: '#3a2613' #'#008000'
  dims: {width: 820, height: 670}
  game_spec: window.ALL_GAMES.tichu

  make_mode_handlers: (canv_root, gc, player_id) ->
    root = new BorderFrame {
      forced_dims: {width: 800, height: 650}
      background: '#d2b699' #'#008000'
    }
    canv_root.add root, 10, 10

    shared =
      ui: new SharedUI gc, player_id, root
      scoreboard: new ScoreBoard gc
    ($ '#right-column').prepend shared.scoreboard.elt()
    return {
      Main: (new MainController gc, root, shared)
      Pass: (new PassController gc, player_id, root, shared)
      Play: (new PlayController gc, player_id, root, shared)
      PickDragon: (new PickDragonController gc, player_id, root, shared)
      GrandTichu: (new GrandTichuController gc, player_id, root, shared)
    }
}
