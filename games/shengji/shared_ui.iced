mustache_m = require 'mustache'

{Button, TextBox} = require 'canvas/window.iced'
{HBox, VBox, BorderFrame} = require 'canvas/container.iced'

{CardGraphics} = require 'canvas/card_graphics.iced'
{OpponentHands} = require 'canvas/four_player.iced'


class ScoreBoard
  render_to_jquery = (tmpl, params) ->
    html = mustache_m.to_html tmpl, params
    return $ html
  SCOREBOARD_TMPL = '''
  <table>
    <tr>
      <td>{{team1}}</td><td>{{team2}}</td>
    </tr>
    <tr>
      <td>{{score1}}</td><td>{{score2}}</td>
    </tr>
  </table>
  '''

  constructor: (@gc) ->
    @_elt = $ '<div class="scoreboard"></div>'

  elt: -> @_elt

  update: ->
    team_name = (team_num) =>
      """#{@gc.username_for_player team_num} / \
      #{@gc.username_for_player (team_num + 2)}"""
    team_score = (team_num) =>
      level = '' + @gc.state().players[team_num].level
      if (@gc.state().master % 2) == team_num
        level += '*'
      return level

    inner_elt = render_to_jquery SCOREBOARD_TMPL, {
      team1: (team_name 0), score1: (team_score 0),
      team2: (team_name 1), score2: (team_score 1)
    }
    @_elt.empty()
    @_elt.append inner_elt


class PlayerInfo
  constructor: (@gc, @player_id) ->
    @_elt = new BorderFrame {
      forced_dims: {width: 90, height: 70}
    }
    @_info = new TextBox {
      size: 12
    }
    @_elt.set_child 'center', @_info

  update: ->
    player = @gc.state().players[@player_id]
    if @gc.state().master is @player_id
      @_elt.set_opts {border: 'red'}
    else
      @_elt.set_opts {border: null}
    txt = "#{@gc.username_for_player @player_id}"
    txt += "\n#{player.points} points"
    @_info.set_text txt

  elt: -> @_elt

exports.make_opp_hands = (gc, player_id) ->
  opp_info = []
  info_elts = {}
  for pos, idx in ['left', 'top', 'right']
    pid = (player_id + idx + 1) % 4
    info = new PlayerInfo gc, pid
    opp_info.push info
    info_elts[pos] = info.elt()

  get_hand_size = (player_id) =>
    gc.state().players[player_id].cards.length
  opp_hands = (new OpponentHands player_id,
               CardGraphics, get_hand_size,
               {info_elts})
  return {
    elt: opp_hands
    update: ->
      for info in opp_info
        info.update()
      opp_hands.update()
  }

exports.ScoreBoard = ScoreBoard
exports.PlayerInfo = PlayerInfo