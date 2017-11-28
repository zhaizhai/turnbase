assert = require 'assert'
{R} = require 'client/lib/R.iced'
canvas_util_m = require 'canvas/canvas_util.iced'


# TODO: specify the CardGraphics interface more explicitly
class CardGraphics
  @CARD_WIDTH = 72
  @CARD_HEIGHT = 108

  SUIT_TO_IDX = {C: 0, D: 3, H: 2, S: 1}

  @get_resource = ->
    R.Image 'basic-cards', {
      url: '/canvas/cards/basic-cards.png'
      width: 995
      height: 569
    }

  @_img = null

  @_load_img = ->
    return if @_img?
    @_img = R.get_img 'basic-cards'
    assert @_img?

  @draw_back = (ctx, x, y, w = @CARD_WIDTH, h = @CARD_HEIGHT) ->
    r = 4
    ctx.fillStyle = 'red'
    canvas_util_m.fillRoundRect ctx, x, y, w, h, r
    ctx.strokeStyle = 'black'
    canvas_util_m.strokeRoundRect ctx, x, y, w, h, r

  @draw_card = (ctx, card, x, y, w = @CARD_WIDTH, h = @CARD_HEIGHT) ->
    @_load_img()

    if card.value is 1 # joker
      card_y = 5 + (@CARD_HEIGHT + 4) * 4
      card_x = if card.suit in 'CDHS'
        4 + (@CARD_WIDTH + 4) * (1 + SUIT_TO_IDX[card.suit])
      else
        4
      ctx.drawImage @_img, card_x, card_y,
        (@CARD_WIDTH + 2), (@CARD_HEIGHT + 2),
        x, y, w, h
      return

    if card.suit not of SUIT_TO_IDX
      throw new Error "Unhandled suit #{card.suit}"
    card_y = 5 + (@CARD_HEIGHT + 4) * SUIT_TO_IDX[card.suit]

    val_idx = card.value - 2
    card_x = 4 + (@CARD_WIDTH + 4) * val_idx

    ctx.drawImage @_img, card_x, card_y,
      (@CARD_WIDTH + 2), (@CARD_HEIGHT + 2),
      x, y, w, h

exports.CardGraphics = CardGraphics
