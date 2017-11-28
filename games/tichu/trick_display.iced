util_m = require 'shared/util.iced'

window_m = require 'canvas/window.iced'
{Button, TextInfo, TextBox} = window_m

{MixinClass} = require 'canvas/mixin.iced'
{CanvElement} = require 'canvas/adapter.iced'

{TichuCardGraphics} = require 'games/tichu/tichu_card_graphics.iced'
{CardHand} = require 'canvas/cards/card_hand.iced'


POSITIONS = [
  [0, 1] # bottom
  [-1, 0] # left
  [0, -1] # top
  [1, 0] # right
]
TrickDisplay = MixinClass 'TrickDisplay', [CanvElement],
  constructor: (@gc, @player_id, opts) ->
    {@width, @height} = opts
    @_first = 0
    @_cards = [null, null, null, null]

  mouse_evt: ->

  update: ->
    @_cards = []
    trick = @gc.state().cur_trick
    idx = trick.cards.length - 1
    # TODO: can idx be < 0?

    cur_turn = @gc.state().cur_turn
    @_first = (cur_turn - @player_id + 4) % 4
    for i in [0...4]
      cur_player = (cur_turn - i + 3) % 4
      if idx >= 0
        if cur_player is trick.players[idx]
          ch = new CardHand TichuCardGraphics, {peek_ratio: 0.3}
          ch.set_hand trick.cards[idx]
          @_cards.push ch
          idx -= 1
        else
          @_cards.push new TextBox {
            size: 25
            text: 'Passed'
            align: 'center'
          }
      else # didn't play
        @_cards.push null

    @_cards.reverse()
    console.log 'cards', @_cards

  render: (ctx) ->
    for cards, i in @_cards
      continue if not cards?

      idx = (@_first + i) % 4
      scaling = 0.7
      [x, y] = POSITIONS[idx]
      [x, y] = [x * @width / 4, y * @height / 4]
      [x, y] = [x + (@width / 2), y + (@height / 2)]
      [x, y] = [x - scaling * (cards.width / 2),
                y - scaling * (cards.height / 2)]

      ctx.save()
      ctx.translate x, y
      ctx.scale scaling, scaling
      cards.render ctx
      ctx.restore()

exports.TrickDisplay = TrickDisplay
