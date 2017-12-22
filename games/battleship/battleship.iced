assert = require 'assert'
Turnbase = require 'game_engine/turnbase.iced'
T = Turnbase.T
V = Turnbase.V
util_m = require 'shared/util.iced'

# Declares a data structure called `Ship`, containing data associated
# with one ship. The data structure is specified by one or more field
# names, each carrying a *typespec* which describes the type of value
# that is valid for that field.
Ship = Turnbase.struct 'Ship', {
  # The length of the ship. The object T.Integer is a placeholder that
  # lets the Turnbase framework know that the value should be an
  # integer.
  length: T.Integer
  # The number of cells of the ship that haven't been hit yet. The
  # ship is sunk when `health` is zero. However, we don't want to
  # reveal which ship was hit to the other player. The T.MaskedInteger
  # typespec serves this purpose: it is a special type whose value is
  # *masked*, i.e. it is only revealed to some players. We will see
  # later exactly how it is used.
  health: T.MaskedInteger
}


# Declares a data structure for each player.
Player = Turnbase.struct 'Player', {
  # The list of ships the player has. T.ArrayOf(Ship) is a compound
  # typespec whose meaning is self-explanatory: an array of Ships.
  ships: T.ArrayOf(Ship)
  # The grid of guesses made about your opponents ships. The possible
  # values for cells are "hit", "miss", or null (meaning not guessed
  # yet).
  #
  # The Turnbase framework has a built-in type T.Grid, since grids are
  # commonly used in games. A T.Grid object has methods get(x, y),
  # set(x, y, value), and in_range(x, y).
  guesses: T.Grid(T.String)
  # The grid of integers storing where the ships are. The value of
  # each cell is the number of the ship occupying that cell, or null
  # if no ship is there.
  #
  # T.Masked turns a type into a masked version of the type. Opponents
  # will not be allowed to see this grid.
  placements: T.Masked(T.Grid(T.Integer))

  # Turnbase structures can also have functions attached to
  # them. These are similar to instance methods in Java or member
  # functions in C++. This one returns whether the given ship can be
  # placed at (x, y).
  can_place: (ship_num, x, y, is_vertical) ->
    ship = @ships[ship_num]
    to_place = if is_vertical
      ([x, y + k] for k in [0...ship.length])
    else
      ([x + k, y] for k in [0...ship.length])
    for [x2, y2] in to_place
      # Note: reaching this line from a client that does not have
      # access to the masked object @placements will result in an
      # error. This will never happen for us, because you will only
      # need to test placements for your own ships.
      if not @placements.in_range(x2, y2)
        return false
      cur = @placements.get(x2, y2)
      if cur? and (cur isnt ship_num)
        return false
    return true

  # Returns whether all ships have been placed.
  all_placed: ->
    placed = (false for ship in @ships)
    for x in [0...@placements.height]
      for y in [0...@placements.width]
        ship_num = @placements.get(x, y)
        if ship_num?
          placed[ship_num] = true
    return util_m.all(placed)
}

# Declares the base state of the game. In this case, we only need an
# array of all the players (the array will always be of length 2). In
# other games, the state might additionally include other state shared
# by all players, such as a shared deck to draw from.
Turnbase.state {
  players: T.ArrayOf Player
}

Turnbase.setup {
  # The `init` function creates the initial state for the game. The
  # return type must match the type specified in `Turnbase.state()`.
  #
  # The passed in argument `initial_data` contains data that may be
  # needed for constructing this initial state. For example, if you
  # want to allow different numbers of players, the number of players
  # will be available as `initial_data.num_players`. To keep things
  # simple, we won't use this feature in the tutorial.
  init: (initial_data) ->
    assert initial_data.num_players == 2
    players = []
    for player_num in [0...2]
      ships = []
      for l in [2, 3, 4, 5]
        # By default, a T.MaskedInteger is not accessible to anyone
        health = new T.MaskedInteger l
        # Make the health accessible to the current player
        health.add_access player_num
        ships.push (new Ship {length: l, health: health})

      player = new Player {
        ships: ships
        # A grid must be initialized with a width and a height. By
        # default, all cells of the grid will be initialized to
        # `null`.
        placements: {width: 8, height: 8}
        guesses: {width: 8, height: 8}
      }
      # Let the current player see their own placements.
      player.placements.add_access player_num
      players.push player

    return {players: players}
}


# A Turnbase *mode* is a grouping of related states in a game. Just as
# there are different ways to break up the code for a program into
# functions, there are different ways to organize a game into
# modes. In this tutorial, we will break up the game of Battleship
# into two modes:
#
# 1. 'Place': The players choose where to put their ships.
# 2. 'Guess': The players guess where their opponent's ships are.

Turnbase.mode 'Place', {
  # In the definition of a mode, a typespec defines additional state
  # relevant to that mode.
  #
  # This one records whether each player is done placing.
  is_done: T.ArrayOf(T.Boolean)

  # A function defines an *action*, described in more detail
  # below. When we are in the Place mode, each player may take the
  # action of 'place' with the specified arguments (subject to
  # validation to see if the action is allowed). Provided that the
  # action is allowed, this will cause some change in the game
  # state. Thus, actions specify exactly what kinds of changes to the
  # game state are allowed.
  place: (ship_num, x, y, is_vertical) ->
    # Actions must return an object with the fields "types", "validate", and "execute".
    #
    # The `types` field specifies the types of the arguments. This one
    # says that `ship_num`, `x`, and `y` are integers, while
    # `is_vertical` is a boolean.
    types: [T.Integer, T.Integer, T.Integer, T.Boolean]
    # The `validate` field is a function that checks whether the
    # action is valid. This is done through making `V.assert`
    # statements. `V.assert` takes two arguments: the condition to be
    # checked, and the error message to report if the check fails.

    validate: ->
      # The additional state defined earlier can be accessed as
      # `@is_done`. The special property @PLAYER is automatically
      # populated with the number of the player who initiated the
      # action.
      V.assert (not @is_done[@PLAYER]), "Already done placing!"
      # We can also access the players field from the base game state
      # as `@players`.
      V.assert (0 <= ship_num < @players[@PLAYER].ships.length), "Ship number #{ship_num} out of range!"
      orientation = if is_vertical then "vertically" else "horizontally"
      V.assert @players[@PLAYER].can_place(ship_num, x, y, is_vertical),
        "Can't place ship #{ship_num} #{orientation} at (#{x}, #{y})!"

    # The `execute` field is a function that actually carries out the
    # action. It is only called if the validation is passed.
    execute: ->
      player = @players[@PLAYER]
      grid = player.placements
      ship = player.ships[ship_num]

      for cx in [0...grid.height] # TODO: explain that row/column are flipped
        for cy in [0...grid.width]
          # remove previous placement of the ship
          if grid.get(cx, cy) is ship_num
            grid.set(cx, cy, null)

          # new placement of ship
          if is_vertical
            if (cx == x and y <= cy < y + ship.length)
              grid.set(cx, cy, ship_num)
          else
            if (cy == y and x <= cx < x + ship.length)
              grid.set(cx, cy, ship_num)

  # Taking this action indicates that you're done placing your ships.
  done: ->
    types: []
    validate: ->
      V.assert (not @is_done[@PLAYER]), "Already done!"
      V.assert @players[@PLAYER].all_placed(), "Not all ships have been placed yet!"
    execute: ->
      @is_done[@PLAYER] = true
      if util_m.all(@is_done)
        # The special function @LEAVE_MODE() causes the game to exit the current mode.
        return @LEAVE_MODE()
}


Turnbase.mode 'Guess', {
  # The player whose turn it is.
  cur_turn: T.Integer

  # The action
  guess: (x, y) ->
    types: [T.Integer, T.Integer]
    validate: ->
      V.assert (@PLAYER is @cur_turn), "It's not your turn to guess!"
      V.assert (0 <= x < 8 and 0 <= y < 8), "Out of range!"
      V.assert (@players[@PLAYER].guesses.get(x, y) is null), "Already guessed there!"
    execute: ->
      me = @players[@PLAYER]
      other = @players[1 - @PLAYER]
      ship_num = other.placements.get(x, y)

      # This string uses a special syntax that later gets replaced by
      # the player's username. For example, any appearance of %{0} in
      # the string will be replaced by the username of player 0.
      message = "%{#{@PLAYER}} guesses (#{x}, #{y})... "
      if ship_num?
        ship = other.ships[ship_num]
        me.guesses.set(x, y, "hit")
        # Since `ship.health` is a T.MaskedInteger, we have to
        # access/modify it using `get()` and `set()` methods.
        ship.health.set(ship.health.get() - 1)
        # The special function @LOG displays a message in the chat to all users.
        @LOG(message + "Hit!")
      else
        me.guesses.set(x, y, "miss")
        @LOG(message + "Miss.")
      @LEAVE_MODE()
}


# The main game loop. This is the entry point for starting the game,
# analogous to the "main" function in C or Java.
Turnbase.main ->
  # Enter the 'Place' mode. The additional state `is_done` must be
  # initialized when entering the mode.
  await @ENTER_MODE 'Place', {is_done: [false, false]}, defer()

  # We won't reach here until after leaving the Place mode.
  cur_turn = 0
  while true
    # Enter the 'Guess' mode for the current player.
    await @ENTER_MODE 'Guess', {cur_turn: cur_turn}, defer()

    other = (cur_turn + 1) % 2
    # Check whether the other player has lost.
    if util_m.all ((ship.health.get() == 0) for ship in @players[other].ships)
      @LOG "%{#{other}} has no ships left. %{#{cur_turn}} wins!"
      break

    # It's now the other player's turn.
    cur_turn = other

  # Reveal each player's ship placements to the other
  @players[0].placements.add_access(1)
  @players[1].placements.add_access(0)
  # The special function @GAME_OVER() ends the game.
  @GAME_OVER()
