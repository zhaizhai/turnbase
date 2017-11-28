mustache_m = require 'mustache'
{$ajax} = require 'client/lib/http_util.iced'

# TODO: uhh... does this automatically sanitize html? oh well it's
# only testing
compile_tmpl = (tmpl, args) ->
  return $ (mustache_m.to_html tmpl, args)

TMPL = '''
  <div class="choice-container">
    <div>
      <button class="pick-test">Pick</button>
      <button class="delete-test">Delete</button>
    </div>
    <div>{{desc}}</div>
  </div>
'''

window.onload = ->
  {choices, game_type} = window.TEMPLATE_PARAMS

  for choice in choices
    elt = compile_tmpl TMPL, {
      desc: choice.desc
      game_id: choice.game_id
      game_type: game_type
    }

    do (choice) ->
      (elt.find '.pick-test').click ->
        pick_url = "/testing/#{game_type}?game_id=#{choice.game_id}"
        window.location = pick_url
      (elt.find '.delete-test').click ->
        await $ajax.post '/testing/delete', {
          game_id: choice.game_id
        }, defer err, res
        console.log 'delete', err, res
        unless err
          location.reload()
    ($ '#choices-container').append elt