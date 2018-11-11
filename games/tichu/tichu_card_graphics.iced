assert = require 'assert'
{R} = require 'client/lib/R.iced'
canvas_util_m = require 'canvas/canvas_util.iced'

class TichuCardGraphics
  @CARD_WIDTH = 90
  @CARD_HEIGHT = 126

  SUIT_TO_IDX = {C: 0, D: 3, H: 2, S: 1}

  @_img = null
  @_load_img = ->
    return if @_img?
    @_img = R.get_img 'tichu-cards'
    assert @_img?

  @_draw_border = (ctx, x, y, w, h) ->
    r = 4
    ctx.strokeStyle = 'black'
    canvas_util_m.strokeRoundRect ctx, x, y, w, h, r

  @draw_back = (ctx, x, y, w = @CARD_WIDTH, h = @CARD_HEIGHT) ->
    @_load_img()
    ctx.drawImage @_img, 0, 0, 90, 126, x, y, w, h
    # r = 4
    # ctx.fillStyle = 'red'
    # canvas_util_m.fillRoundRect ctx, x, y, w, h, r
    @_draw_border ctx, x, y, w, h

  @draw_card = (ctx, card, x, y, w = @CARD_WIDTH, h = @CARD_HEIGHT) ->
    @_load_img()

    for special, idx in ['phoenix', 'dragon', 'dog', 'mahjong']
      if card.suit is special
        card_x = 90 * (idx + 1)
        ctx.drawImage @_img, card_x, 0, 90, 126, x, y, w, h
        @_draw_border ctx, x, y, w, h
        return

    if card.suit not of SUIT_TO_IDX
      throw new Error "Unhandled suit #{card.suit}"
    card_y = 126 * (1 + SUIT_TO_IDX[card.suit])

    val_idx = if card.value is 14 then 0 else (card.value - 1)
    card_x = 90 * val_idx

    ctx.drawImage @_img, card_x, card_y, 90, 126, x, y, w, h
    @_draw_border ctx, x, y, w, h

exports.TichuCardGraphics = TichuCardGraphics
