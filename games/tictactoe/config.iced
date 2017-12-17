# Each game must have a configuration file in its directory named
# `config.iced`. It is automatically detected and describes basic
# info about the game.

exports.CONFIGS =
  disabled: false
  display_name: 'Tic Tac Toe'
  js_deps: ['&jquery']
  css_deps: []
  # If the line below is commented out, a default client will be
  # created that displays the raw game state (this is useful for
  # testing/prototyping).
  client: 'ui.iced'
  default_num_players: 2
