TurnbaseClient = require 'game_engine/client/setup.iced'

# These are the canvas UI elements that we will use to build our UI.
{Button, TextBox, InvisibleBox} = require 'canvas/window.iced'
{BorderFrame, VBox} = require 'canvas/container.iced'
{Table} = require 'canvas/table.iced'

# A handler for the 'Play' mode. A mode handler must implement the
# following two methods:
#
#   `update`: called immediately after the mode is entered or any player performs an action.
#   `cleanup`: called when the mode is left.
class PlayHandler
  # Gives the display text for the value of a Tic-Tac-Toe cell.
  text_from_val = (val) ->
    if not val? then return '__'
    return if (val == 0) then 'X' else 'O'

  # PlayHandler is initialized with the following data:
  #
  # @game_client: A GameClient instance (this will be provided by
  #   the framework). This provides the interface for reading the game
  #   state, taking actions, etc.
  # @player_id: The id of the player using this client
  #   (0 <= @player_id < total number of players).
  # @root_elt: The root canvas UI element, which will be a
  #   BorderFrame. A BorderFrame is a container element which can hold
  #   child elements in top, bottom, left, right, and center
  #   positions:
  #    ___________________________
  #   |      |     top     |      |
  #   |      |_____________|      |
  #   |      |             |      |
  #   | left |    center   | right|
  #   |      |_____________|      |
  #   |      |    bottom   |      |
  #   |______|_____________|______|
  #
  constructor: (@game_client, @player_id, @root_elt) ->

  # The text saying whose turn it is.
  _turn_text: ->
    cur_turn = @game_client.state().cur_turn
    if @player_id is cur_turn
      return "Your move."
    else
      return "#{(@game_client.username_for_player cur_turn)}'s move."

  # Makes a cell of the 3x3 Tic-Tac-Toe grid at the specified row and column.
  _make_cell: (row, col) ->
    val = @game_client.state().grid.get(row, col)
    # The returned element is a button.
    return new Button {
      width: 80, height: 80
      # Disable the button if you can't play there.
      disabled: val?
      size: 40, text: (text_from_val val)
      # When clicked, play in the given cell. Calling `submit_action`
      # sends the action to the server which then updates all clients.
      handler: => @game_client.submit_action 'play', [row, col]
    }

  # This function constructs the UI given the current game state.
  update: ->
    # The UI element where messages like "Your turn" will be
    # displayed. A VBox is a container for other UI elements, stacking
    # them vertically.
    mesg_elt = new VBox {}, [
      # An InvisibleBox with height 120 is used to add 120 pixels of
      # vertical spacing.
      (new InvisibleBox 0, 120)
      # A TextBox simply displays some text.
      new TextBox { size: 28, align: 'center', text: @_turn_text() }
    ]
    # We place the message element in the top area of the root
    # container.
    @root_elt.set_child 'top', mesg_elt

    # The UI element for the Tic-Tac-Toe grid. A Table is a grid of UI
    # elements, with one element in each cell.
    grid = new Table 3, 3, { padding: 12 }
    for r in [0...3]
      for c in [0...3]
        grid.set_cell r, c, (@_make_cell r, c)
    @root_elt.set_child 'center', grid

  # Clean up UI elements that are no longer needed outside of this
  # mode.
  cleanup: ->
    @root_elt.set_child 'top', null
    @root_elt.set_child 'center', null


# Calling `setup` configures the TurnbaseClient. The framework will do
# the rest.
TurnbaseClient.setup {
  # The dimensions of the canvas element where the UI will be drawn.
  dims: {width: 600, height: 600}
  # The background color of the canvas element.
  background: '#aaaadd'
  # A magic incantation that's needed to specify which game we're
  # playing. (In the future, we will handle this automatically.)
  game_spec: window.ALL_GAMES.tictactoe

  # This function gets called once the game is initialized. The value
  # returned should be an object with key-value pairs providing
  # handlers for each mode. The arguments passed are:
  #
  # canvas_base: A Frame UI element covering the entire canvas. A Frame
  #   is a container which can hold arbitrary child elements at
  #   specified pixel offsets.
  #
  # game_client: A GameClient instance to be passed to mode handlers.
  make_mode_handlers: (canvas_base, game_client) ->
    # The root canvas element. We use a BorderFrame rather than the
    # raw Frame for more convenient layout.
    root_elt = new BorderFrame {
      # This forces the size of the BorderFrame. Otherwise, the size
      # will adjust according to the sizes of its children.
      forced_dims: {width: canvas_base.width, height: canvas_base.height}
    }
    # We add the root element to the raw Frame. Using x- and y-offsets
    # of 0 means that our root element takes up the whole canvas.
    canvas_base.add root_elt, 0, 0
    return {
      Play: (new PlayHandler game_client, game_client.player_id, root_elt)
    }
}
