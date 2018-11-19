assert = require 'assert'
EventEmitter = (require 'events').EventEmitter

util_m = require 'shared/util.iced'
struct_m = require 'shared/T/struct.iced'
{T, struct} = struct_m

poll_server_m = require 'server/poll_server.iced'
{LinearDataProvider} = poll_server_m

{GameSpec} = require 'game_engine/game_spec.iced'

class GameTable
  constructor: (@game_id, @game_spec, opts) ->
    assert @game_spec instanceof GameSpec

    {initial_data, seed} = opts
    initial_data.num_players ?= @game_spec.default_num_players
    @num_players = initial_data.num_players
    assert @num_players?, "Number of players is not specified!"
    @game_controller = @game_spec.make_instance initial_data, seed

    @_poll_provider = new LinearDataProvider (cid, log_entry) =>
      return @game_controller.package_log_entry cid, log_entry

    @_game_over = false

  game_over: -> @_game_over
  get_type: -> @game_spec.name

  page_info: ->
    js_deps = @game_spec.js_deps.slice()
    for dep, idx in js_deps
      if dep[0] isnt '&'
        # TODO: temporary hack
        js_deps[idx] = '../games/' + dep
    js_deps.push "../games/bundles/#{@game_spec.name}_bundle.iced"
    js_deps = js_deps.concat ['&markdown', 'nav_bar.iced']

    return {
      js_deps: js_deps
      css_deps: @game_spec.css_deps.slice()
    }

  get_snapshot: (player_id) ->
    json = @game_controller.gs.snapshot player_id
    cursor = @_poll_provider.get_cursor()
    return {
      snapshot:
        mode_name: @game_controller.gs.mode().name
        json: json
      game_over: @_game_over
      poll_from: cursor
    }

  get_poll_provider: -> @_poll_provider

  get_action_log: ->
    action_log = []
    entries = @game_controller.log.entries_since 0
    for entry in entries
      if entry.op isnt 'ACTION' then continue
      action_log.push {
        action_name: entry.action
        player_id: entry.player_id
        args: (util_m.clone entry.args)
      }
    return action_log

  perform_action: (action) ->
    if @_game_over
      return {success: false, reason: "Game is over!"}
    console.log 'received action:', action
    {action_name, player_id, args} = action

    # TODO: validate types of arguments here?

    {entries, reason} = @game_controller.action player_id, action_name, args
    if not entries?
      return {success: false, reason: reason}

    for entry in entries
      entry.player_id = player_id # TODO: is this needed?
    @_poll_provider.add_data_batch entries

    # TODO: handle game over
    # if result.log.game_over
    #   console.log 'game ended!'
    #   @_game_over = true
    return {success: true}

exports.GameTable = GameTable
