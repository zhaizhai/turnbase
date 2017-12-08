#!/usr/local/bin/iced

fs = require 'fs'
iced = require 'iced-coffee-script'

compile_iced = (module, filename) ->
  src = fs.readFileSync(filename, 'utf8')
  js = iced.compile(src)
  return module._compile(js, filename)

require.extensions['.iced'] = compile_iced
require.extensions['.coffee'] = compile_iced

Jasmine = require 'jasmine'
jasmine = new Jasmine

game_name = process.argv[2]
if not game_name?
  console.log "You must specify the name of a game to test."
  process.exit()

jasmine.loadConfig {
  spec_dir: "games/#{game_name}"
  # TODO: allow multiple test files
  spec_files: ['test.iced']
  helpers: []
}
jasmine.execute()
