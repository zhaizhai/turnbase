exports.GAMES = {}
exports.LOGIN_SECRET = if process.env.TURNBASE_SECRET?
  process.env.TURNBASE_SECRET
else
  console.log "WARNING: RUNNING SERVER WITH INSECURE SECRET abc123"
  'abc123'
