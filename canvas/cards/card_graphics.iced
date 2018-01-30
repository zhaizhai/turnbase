assert = require 'assert'
{R} = require 'client/lib/R.iced'
canvas_util_m = require 'canvas/canvas_util.iced'

class CardSet
  DEFAULT_MAPPING = ({suit, value}) ->
    suit_idx = 'CDHS'.indexOf suit
    if value is 1 # joker
      return [4, 1 + suit_idx]

    if suit_idx is -1
      throw new Error "Unhandled suit #{suit}"
    return [suit_idx, (value - 2)]

  constructor: (opts) ->
    @_img_name = opts.img_name
    @_img_resource = R.Image @_img_name, opts.img_data

    @_card_width = opts.card_width
    @_card_height = opts.card_height
    @_x_offset = opts.x_offset ? 0
    @_y_offset = opts.y_offset ? 0
    @_spacing = opts.spacing ? 0
    @_img = null

  _load_img: ->
    if not @_img?
      @_img = R.get_img @_img_name
      assert @_img?

  _draw_card: (ctx, c_row, c_col, x, y, w = @_card_width, h = @_card_height) ->
    @_load_img()
    card_y = @_y_offset + (@_card_height + @_spacing) * c_row
    card_x = @_x_offset + (@_card_width + @_spacing) * c_col
    ctx.drawImage @_img, card_x, card_y,
      (@_card_width + 2), (@_card_height + 2), # TODO: why expand by 2?
      x, y, w, h

  get_resource: -> @_img_resource

  get_graphics: (mapping = DEFAULT_MAPPING) ->
    return {
      CARD_WIDTH: @_card_width, CARD_HEIGHT: @_card_height
      draw_back: (ctx, x, y, w = @_card_width, h = @_card_height) =>
        r = 4
        ctx.fillStyle = 'red'
        canvas_util_m.fillRoundRect ctx, x, y, w, h, r
        ctx.strokeStyle = 'black'
        canvas_util_m.strokeRoundRect ctx, x, y, w, h, r
      draw_card: (ctx, card, x, y, w = @_card_width, h = @_card_height) =>
        [r, c] = mapping card
        @_draw_card ctx, r, c, x, y, w, h
    }

exports.ClassicCards = new CardSet {
  img_name: 'basic-cards', img_data: {
    url: '/resources/basic-cards.png'
    width: 995
    height: 569
  }
  card_width: 72, card_height: 108
  y_offset: 5, x_offset: 4
  spacing: 4
}
