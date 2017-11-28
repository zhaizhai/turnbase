assert = require 'assert'
util_m = require 'shared/util.iced'

{MixinClass} = require 'canvas/mixin.iced'
{CanvElement, ChildList, MouseAdapter, ChildRender, ChildMap} = require 'canvas/adapter.iced'

{space_rectangle} = require 'canvas/layout_util.iced'

NBorderFrame = MixinClass 'NBorderFrame', [
  CanvElement, ChildMap, ChildRender, MouseAdapter
],
  constructor: (@n, opts) ->
    if typeof @n isnt 'number' or @n <= 1
      throw new Error "Invalid n #{@n}"

    {@dims, @margin} = opts
    if not @dims? or not @margin?
      throw new Error "Invalid opts!"
    # positions are [0...@n] and 'center'
    {@width, @height} = @dims

  layout: ->
    # {@width, @height} = @dims
    [w, h] = [@width - 2 * @margin, @height - 2 * @margin]

    center = @get_child 'center'
    if center?
      center.x = (@width - center.elt.width) / 2
      center.y = (@height - center.elt.height) / 2

    positions = space_rectangle w, h, @n
    for {x, y}, idx in positions
      child = @get_child idx
      if child?
        child.x = @margin + x - (child.elt.width / 2)
        child.y = @margin + y - (child.elt.height / 2)

    @set_dirty true
    @parent.layout() if @parent?

  render: (ctx) ->
    @render_children ctx

exports.NBorderFrame = NBorderFrame