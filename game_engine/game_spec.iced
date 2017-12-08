log = (require 'shared/log.iced') 'game_spec.iced'
assert = require 'assert'
{GameController} = require 'game_engine/game_controller.iced'
turnbase = require 'game_engine/turnbase.iced'
util_m = require 'shared/util.iced'

class GameSpec
  REQUIRED = # TODO: validate types probably too?
    display_name: null
    js_deps: null
    css_deps: null
    base: null # object w/ base fields
    modes: null
    setup:
      options: null
      defaults: null
      init: null
    default_num_players: null

  DEFAULTS =
    rules_md: null
    has_bots: false

  constructor: (@name) ->
    game_path = "games/#{@name}"

    {CONFIGS} = require "#{game_path}/config.iced"
    for k, v of CONFIGS
      @[k] = v

    turnbase.create name
    require "#{game_path}/#{@name}.iced"

    tb = turnbase.get()
    tb.extend_spec @

    for k, v of REQUIRED
      assert @[k]?, "Game spec is missing field #{k}!"
    if @setup.defaults.num_players?
      log.warn "Ignoring initial data `num_players`: overridden by `default_num_players` in config.iced."

    for k, v of DEFAULTS
      @[k] ?= v

  make_instance: (initial_data, seed = null) ->
    initial_data.num_players ?= @default_num_players
    for k, v of @setup.defaults
      initial_data[k] ?= v

    return (new GameController @, initial_data, seed)


exports.GameSpec = GameSpec