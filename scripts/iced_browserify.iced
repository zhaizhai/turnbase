#!/usr/local/bin/iced

{JsCache} = require 'server/templates.iced'

if process.argv.length < 3
  console.log 'Missing argument!'
  process.exit()

jc = new JsCache
await jc._compile process.argv[2], defer err, js_string
if err
  console.log 'Error:', err
else
  console.log js_string