assert = require 'assert'
{EventEmitter} = require 'events'

templates_m = require 'server/templates.iced'
util_m = require 'shared/util.iced'

poll_server_m = require 'server/poll_server.iced'
{PollProvider, LatestDataProvider} = poll_server_m

{GameTable} = require 'server/game_table.iced'
User = (require 'server/user.iced').User

{StaleTracker} = require 'shared/timer.iced'
{BotServerRPC} = require 'bots/bot_rpc.iced'

# event: players-changed
class TableServer extends EventEmitter
  # grace period before reap
  GRACE_PERIOD_MS =
    'no-players': 60 * 1000
    'not-enough-players': 60 * 60 * 1000
    # # TODO: before enabling this, we need to make sure bots know what
    # # to do when their table is deleted
    #'last-activity': 24 * 60 * 60 * 1000

  # TODO: come up with more principled way of generating game ids
  make_game_id = ->
    return 'tmpg' + (util_m.rand_int 1000000)

  constructor: (@tid, @game_spec, @table_opts, @poll_server, @user_store) ->
    @table = new GameTable make_game_id(), @game_spec, @table_opts
    @party_mode = @table_opts.party_mode ? false

    @poll_server.register_provider "#{@tid}:game:#{@table.game_id}", @table.get_poll_provider()

    @users = []
    for i in [0...@table.num_players]
      @users.push null
    @owner_queue = []
    @_stale_tracker = new StaleTracker
    @_stale_tracker.mark 'no-players', 'not-enough-players', 'last-activity'

    @_info_provider = new LatestDataProvider (cid, cb) =>
      return cb null, @_get_table_info()
    @poll_server.register_provider "#{@tid}:info", @_info_provider

  destroy: ->
    # TODO: ensure no race conditions arising from ongoing requests
    @removeAllListeners()
    @poll_server.remove_provider "#{@tid}:game:#{@table.game_id}"
    @poll_server.remove_provider "#{@tid}:info"

  rematch: ->
    # TODO: check that existing game has ended
    console.log "Rematch on table #{@tid}!"
    # TODO: handle new game opts (e.g. more or fewer players)
    @poll_server.remove_provider "#{@tid}:game:#{@table.game_id}"
    # TODO: more steps needed to destruct old table?
    @table = new GameTable make_game_id(), @game_spec, @table_opts
    @poll_server.register_provider "#{@tid}:game:#{@table.game_id}", @table.get_poll_provider()
    @_info_provider.update()

  _get_table_info: ->
    return {
      game_id: @table.game_id
      users: ((if user? then (User.dump_json user) else null) for user in @users)
      owner: @_owner()
    }

  _is_valid: (player_id) ->
    return (0 <= player_id < @users.length)

  _owner: ->
    if @owner_queue.length == 0
      return null
    return @_uid_for_player_id @owner_queue[0]

  _user_for_player_id: (player_id) ->
    if not @users[player_id]?
      return null
    return @users[player_id]

  _uid_for_player_id: (player_id) ->
    assert (@_is_valid player_id)
    if not @users[player_id]?
      return null
    return @users[player_id].uid

  _register_player: (user, player_id) ->
    assert (@_is_valid player_id), "Invalid player id! #{player_id}"
    assert not @users[player_id]?
    @users[player_id] = user
    @owner_queue.push player_id

    if (util_m.all (u? for u in @users))
      @_stale_tracker.clear 'not-enough-players'
    @_stale_tracker.clear 'no-players'

    @_info_provider.update()
    @emit 'players-changed'

  _remove_player: (remove_uid, player_id) ->
    assert (@_is_valid player_id)
    player_uid = @users[player_id].uid
    if (remove_uid isnt player_uid and remove_uid isnt @_owner())
      return false

    for pid, idx in @owner_queue
      if pid is player_id
        @owner_queue.splice idx, 1
        break

    @users[player_id] = null

    if (util_m.all (not u? for u in @users))
      @_stale_tracker.mark 'no-players'
    @_stale_tracker.mark 'not-enough-players'

    @_info_provider.update()
    @emit 'players-changed'
    return true

  is_removable: ->
    # TODO: track @table.game_over()
    for name, grace_period of GRACE_PERIOD_MS
      elapsed = @_stale_tracker.time_since_marked name
      if elapsed? and elapsed >= grace_period
        return true
    return false

  authorize: (uid, player_id) ->
    if player_id is -1 then return true
    return (@_uid_for_player_id player_id) == uid

  handle_root: (uid, player_id, device, response) ->
    if not (-1 <= player_id < @table.num_players)
      return response.status(400).send('Invalid player id: #{player_id}')

    js_params =
      tid: @tid
      player_id: player_id
      table_info: @_get_table_info()
      game_type: @game_spec.name
      rules_md: @game_spec.rules_md
      use_mobile_version: (@party_mode and device in ['ios', 'android'])

    if player_id isnt -1
      user = @_user_for_player_id player_id
      if user?.uid isnt uid
        return response.status(400).send('You are not at this table')
      # TODO: should we also populate the username for spectators?
      js_params.username = user.username

    page_info = @table.page_info()
    tmpl_path = 'templates/game_skin.mustache'
    if js_params.use_mobile_version
      tmpl_path = 'templates/game_mobile.mustache'

    await templates_m.render_template tmpl_path, {
      game_name: @game_spec.display_name
      js_params: (JSON.stringify js_params)
      js_deps: page_info.js_deps
      css_deps: page_info.css_deps
    }, defer err, rendered_tmpl

    if err
      console.log "Error rendering template:", err
      return response.status(500).send('Error rendering template!')
    return response.send(rendered_tmpl)

  handle_request_bot: (bot_player_id, response) ->
    # TODO: also specify bot type if there are multiple bots for this
    # game
    await BotServerRPC.request_bot @game_spec.name,
      @tid, bot_player_id, defer err
    if err
      # TODO: figure out proper status code
      return (response.status(400).send "error: #{JSON.stringify err}")
    return (response.send 'ok')

  handle_get_snapshot: (player_id, response) ->
    console.log "snapshot request from player #{player_id}"
    # # TODO: handle permissions
    # if not @authorize uid, player_id
    #   return response.send "Invalid uid/player_id pair"

    ret = @table.get_snapshot player_id
    return (response.send ret)

  handle_join: (uid, player_id, response) ->
    console.log "join request #{uid} on #{player_id}"
    existing_uid = @_uid_for_player_id player_id
    if existing_uid?
      # already have that player id
      return response.send {success: (existing_uid == uid)}

    @user_store.get_user uid, (err, user) =>
      if not user?
        # user doesn't exist
        return response.send {success: false}
      @_register_player user, player_id
      return response.send {success: true}

  handle_kick: (remover_uid, player_id, response) ->
    result = @_remove_player remover_uid, player_id
    if not result
      return response.send("User " + remover_uid + " can't kick player " + player_id)
    return response.send "ok"

  handle_chat: (player_chat, player_id, response) ->
    console.log "====================="
    console.log "chat"
    if player_chat.length > 0
      @table.add_chat (player_id + ": " + player_chat)
    @_stale_tracker.mark 'last-activity'
    return response.send "ok"

  handle_action: (player_id, action, response) ->
    # # TODO: handle permissions
    # if not @authorize uid, player_id
    #   return response.send "Invalid uid/player_id pair"

    # TODO: should we pass the player_id separately or via the action?
    # are there actions that don't need a player_id?
    action.player_id = player_id
    console.log "action", action

    result = @table.perform_action action
    @_stale_tracker.mark 'last-activity'
    console.log "result:", result
    return response.send (if result.success then "ok" else "failed: #{result.reason}")


exports.TableServer = TableServer