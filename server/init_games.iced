assert = require 'assert'
fs = require 'fs'
path = require 'path'
{GameSpec} = require 'game_engine/game_spec.iced'
{GAMES} = require 'server/server_config.iced'

GAMES_DIR = path.join __dirname, '..', 'games'
BUNDLE_DIR = path.join GAMES_DIR, 'bundles'

CLIENT_PREAMBLE = """
turnbase = require 'game_engine/turnbase.iced'
window.ALL_GAMES = {}
"""

plain_client_string = (subdir, config) -> """
require('#{subdir}/#{config.client}')
"""

harness_client_string = (name) -> """
harness_client_m = require 'game_engine/client/harness_client.iced'
window.onload = ->
  harness_client_m.setup window.ALL_GAMES.#{name}
"""

spectator_client_string = (subdir, config) -> """
if window.TEMPLATE_PARAMS.player_id is -1
  require('#{subdir}/#{config.spectator}')
else if window.TEMPLATE_PARAMS.use_mobile_version
  # on mobile
  require('#{subdir}/#{config.mobile_client ? config.client}')
else
  require('#{subdir}/#{config.client}')
"""

client_setup_string = (name) -> """
turnbase.create '#{name}'
require 'games/#{name}/#{name}.iced'
spec =
  name: '#{name}'
config = require 'games/#{name}/config.iced'
for k, v of config.CONFIGS
  spec[k] = v
turnbase.get().extend_spec spec
window.ALL_GAMES.#{name} = spec
"""

MASTER_BUNDLE = CLIENT_PREAMBLE
for file in fs.readdirSync(GAMES_DIR)
  if file is 'bundles' then continue
  subdir = path.join(GAMES_DIR, file)
  if not fs.lstatSync(subdir).isDirectory()
    continue

  game_name = file
  config_path = path.join(subdir, 'config.iced')
  if not fs.existsSync(config_path)
    continue

  bundle = CLIENT_PREAMBLE + '\n\n' + (client_setup_string game_name)
  config = (require config_path).CONFIGS
  if config.disabled
    continue

  console.log "Initializing #{game_name}... CONFIGS =", config
  GAMES[game_name] = new GameSpec game_name

  if config.rules?
    GAMES[game_name].rules_md = fs.readFileSync path.join(subdir, config.rules), 'utf8'

  bundle += "\n\n"
  if config.client?
    if config.spectator?
      bundle += spectator_client_string subdir, config
    else
      bundle += plain_client_string subdir, config
  else
    bundle += harness_client_string game_name

  bundle_path = path.join BUNDLE_DIR, "#{game_name}_bundle.iced"
  fs.writeFileSync bundle_path, bundle

  MASTER_BUNDLE += '\n\n' + (client_setup_string game_name)

fs.writeFileSync (path.join BUNDLE_DIR, 'master_bundle.iced'), MASTER_BUNDLE
