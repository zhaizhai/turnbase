path = require 'path'

class Logger
  LEVEL_FLAGS =
    error: true
    warn: true
    info: true
    debug: true

  BRIGHT = '\x1b[1m'
  COLORS =
    red: "\x1b[31m", green: "\x1b[32m", blue: "\x1b[34m"
    cyan: "\x1b[36m", magenta: "\x1b[35m", yellow: "\x1b[33m"

  LOGGERS =
    info: ['blue', 'INFO', console.log]
    warn: ['yellow', 'WARNING', console.warn]
    error: ['red', 'ERROR', console.error]
    debug: ['magenta', 'DEBUG', console.log]

  constructor: (@filename) ->
    for name of LOGGERS
      @_attach_logger name

  _attach_logger: (name) ->
    [color, disp_text, logger] = LOGGERS[name]
    @[name] = (mesgs...) =>
      if not LEVEL_FLAGS[name]
        return
      prefix = if window? # colors don't work in browser
        "#{disp_text} (#{@filename}):"
      else
        BRIGHT + COLORS[color] + "#{disp_text} (#{@filename}):" + "\x1b[0m"
      logger.call null, prefix, mesgs...

  set_flag: (flag, value) ->
    LEVEL_FLAGS[flag] = value

module.exports = exports = (filename) ->
  if not filename?
    throw new Error "Logger must be initialized with a file name!"
  return new Logger filename
