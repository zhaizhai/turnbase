{T} = require 'shared/T/T.iced'
{V} = require 'shared/T/validation.iced'
Turnbase = require 'game_engine/turnbase.iced'

IntegerGrid = T.Grid T.Integer
Turnbase.state {
  grid: IntegerGrid
  is_winning_for: (player_id) ->
    check = (x, y, dx, dy) =>
      for i in [0...3]
        entry = @grid.get (x + i * dx), (y + i * dy)
        if entry isnt player_id then return false
      return true

    for i in [0...3]
      if (check i, 0, 0, 1) then return true
      if (check 0, i, 1, 0) then return true
    if (check 0, 0, 1, 1) then return true
    if (check 0, 2, 1, -1) then return true
    return false
}

Turnbase.setup {
  init: (initial_data) ->
    return {
      grid: new IntegerGrid {width: 3, height: 3}
    }
}

Turnbase.mode 'Play', {
  cur_turn: T.Integer

  play: (r, c) ->
    types: [T.Integer, T.Integer]
    validate: -> V.check [
        [(@PLAYER is @cur_turn), "Out of turn!"]
        [(@grid.in_range r, c), "Out of range!"]
        [((@grid.get r, c) is null), "Space is occupied!"]
      ]
    execute: ->
      @grid.set r, c, @PLAYER
      @LEAVE_MODE()
}

Turnbase.main ->
  cur_turn = 0
  while true
    await @ENTER_MODE 'Play', {
      cur_turn: cur_turn
    }, defer()

    if @is_winning_for cur_turn
      @LOG "%{#{cur_turn}} wins!"
      break
    cur_turn = (cur_turn + 1) % 2

  @GAME_OVER()
