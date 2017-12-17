{T} = require 'shared/T/T.iced'
{V} = require 'shared/T/validation.iced'
Turnbase = require 'game_engine/turnbase.iced'

# Declares the data structure describing the base state of the
# game.
Turnbase.state {
  # The 3x3 Tic-Tac-Toe grid, which is a grid of integers. A cell
  # contains 0 if player 0 played there, 1 if player 1 played there,
  # and null otherwise.
  grid: T.Grid (T.Integer)
  # Returns whether the current position is winning for the given
  # player.
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
      grid: {width: 3, height: 3}
    }
}

# Declares a *mode*, which is a grouping of related states in a game. The simple game of Tic-Tac-Toe will have only one mode.
Turnbase.mode 'Play', {
  # The player whose turn it is. This variable needs to be set
  # whenever we enter the 'Play' mode.
  cur_turn: T.Integer

  # An action that can be taken by a player.
  play: (r, c) ->
    # Declares that r and c must be integers.
    types: [T.Integer, T.Integer]
    # Validates that the action is allowed.
    validate: ->
      # The special field @PLAYER is set to (the number of) the player
      # initiating the action.
      V.assert (@PLAYER is @cur_turn), "Out of turn!"
      V.assert (@grid.in_range r, c), "Out of range!"
      V.assert ((@grid.get r, c) is null), "Space is occupied!"
    # Performs the action.
    execute: ->
      @grid.set r, c, @PLAYER
      @LEAVE_MODE()
}

# The entry point for starting the game.
Turnbase.main ->
  cur_turn = 0
  while true
    # Repeatedly enter the 'Play' mode...
    await @ENTER_MODE 'Play', {
      cur_turn: cur_turn
    }, defer()

    # ...until a player has won.
    if @is_winning_for cur_turn
      @LOG "%{#{cur_turn}} wins!"
      break
    cur_turn = (cur_turn + 1) % 2

  @GAME_OVER()
