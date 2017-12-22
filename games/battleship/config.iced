# Each game must have a configuration file in its directory named
# `config.iced`. It is automatically detected and describes basic info
# about the game.

exports.CONFIGS =
  # (Default: false) Whether or not the game is disabled. This is
  # sometimes useful for testing purposes or to temporarily disable a
  # game that isn't working.
  disabled: false
  # (Required) The name of the game as it will be displayed to the
  # user.
  display_name: 'Battleship'
  # (Default: []) A list of JavaScript files that need to be . The
  # prefix  (e.g. '&jquery' pulls in the jQuery library).
  js_deps: ['&jquery']
  # (Default: []) A list of CSS files that need to be included for the
  # client .
  css_deps: []
  # (Default: null) The file containing the code for the client UI. If
  # left empty, a default client will be created that displays the raw
  # game state. This is mainly useful for prototyping and testing.
  client: 'ui.iced'
  # (Required) The default number of players for the game.
  default_num_players: 2

# TODO: implement a non-default UI for battleship
