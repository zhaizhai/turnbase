assert = require 'assert'
util_m = require 'shared/util.iced'

{MixinClass} = require 'canvas/mixin.iced'
{CanvElement, ChildList, MouseAdapter, ChildRender} = require 'canvas/adapter.iced'

HiddenCardHand = MixinClass 'HiddenCardHand', [CanvElement],
  constructor: (@_cg, opts) ->
    opts ?= {}
    @_orient = opts.orientation ? 'HORIZ'
    @_peek_ratio = opts.peek_ratio ? 0.2
    @n = opts.n ? 0
    @layout()

  set_num_cards: (@n) ->
    @layout()

  layout: ->
    if @_orient is 'HORIZ'
      @height = @_cg.CARD_HEIGHT
      @width = @_cg.CARD_WIDTH * (1 + (@n - 1) * @_peek_ratio)
    else
      @height = @_cg.CARD_HEIGHT * (1 + (@n - 1) * @_peek_ratio)
      @width = @_cg.CARD_WIDTH
    @set_dirty true
    @parent.layout() if @parent?

  # return top left corner of this card as [x, y]
  _card_location: (idx) ->
    if @_orient is 'HORIZ'
      return [(idx * @_peek_ratio * @_cg.CARD_WIDTH), 0]
    else
      return [0, (idx * @_peek_ratio * @_cg.CARD_HEIGHT)]

  mouse_evt: (evt, x, y) ->

  render: (ctx) ->
    # TODO: have margin
    for i in [0...@n]
      @_cg.draw_back ctx, @_card_location(i)...
    @_draw_num ctx, @n

  # Draws a number over the center of the card.
  # TODO: size of text is hard coded
  _draw_num: (ctx) ->
    if @n == 0
      return
    num = '' + @n
    [x, y] = @_card_location(@n - 1)

    ctx.fillStyle = 'black'
    ctx.textAlign = 'center'
    ctx.font = '20pt Arial'
    ctx.fillText ''+num, x + @_cg.CARD_WIDTH / 2, y + @_cg.CARD_HEIGHT / 2, @_cg.CARD_WIDTH / 3



DISPLAY_ATTRS = ['raised', 'glow', 'invisible', 'draw']
CardHand = MixinClass 'CardHand', [CanvElement],
  constructor: (@_cg, opts) ->
    opts ?= {}
    @_attrs = opts.attrs ? {}
    # takes the form of {attr_name: default_value}
    @_peek_ratio = opts.peek_ratio ? 0.2
    @_raised_ratio = opts.raised_ratio ? 0.2

    @_onclick = null
    @_onhover = null
    @_dragging = false

    @_card_info = []
    if opts.hand?
      @set_hand opts.hand

  _make_info: (card) ->
    ret = {
      card: card, raised: false
      glow: false, invisible: false
      drawn_x: null, drawn_y: null
      draw: null
    }
    util_m.extend ret, @_attrs
    return ret

  layout: ->
    n = @_card_info.length
    @height = (1 + @_raised_ratio) * @_cg.CARD_HEIGHT
    # TODO: account for invisible
    @width = @_cg.CARD_WIDTH * (1 + (n - 1) * @_peek_ratio)
    @set_dirty true
    @parent.layout() if @parent?

  drag: (handler) ->
    # this is actually of the form {start, move, end}
    @_ondrag = handler

  click: (handler) ->
    @_onclick = handler

  hover: (handler) ->
    @_onhover = handler

  mouse_evt: (evt, x, y) ->
    card = (@card_from_coords x, y)
    return unless card?

    if evt is 'down' and not @_dragging
      @_dragging = true
      if @_ondrag?
        @_ondrag.start card
      return
    if evt is 'up' and @_dragging
      @_dragging = false
      if @_ondrag?
        @_ondrag.end card
      return

    if evt is 'move'
      if @_dragging and @_ondrag?
        return @_ondrag.move card
      if @_onhover?
        return @_onhover card
      return
    if evt is 'click'
      return unless @_onclick?
      return @_onclick card

  get_attrs: (idx) ->
    if idx < 0 or idx > @_card_info.length
      throw new Error "index #{idx} out of range!"
    return (util_m.clone @_card_info[idx])

  num_cards: -> @_card_info.length

  insert: (idx, card) ->
    if idx < 0 or idx > @_card_info.length
      throw new Error "index #{idx} out of range!"
    @_card_info.splice idx, 0, (@_make_info card)
    @layout()

  remove: (idx) ->
    if idx < 0 or idx >= @_card_info.length
      throw new Error "index #{idx} out of range!"
    [removed] = @_card_info.splice idx, 1
    @layout()

  move: (from, to) ->
    # TODO: check bounds
    [info] = @_card_info.splice from, 1
    @_card_info.splice to, 0, info
    @layout()

  set_hand: (hand) ->
    # TODO: maybe preserve flags if cards haven't changed
    @_card_info = []
    for card in hand
      @_card_info.push (@_make_info card)
    @layout()

  set_hand_from_info: (card_infos) ->
    @_card_info = []
    for info in card_infos
      {card, orig_index} = info
      new_info = @_make_info card
      new_info.orig_index = orig_index
      # TODO: keep raised part of info?
      @_card_info.push new_info
    @layout()

  # TODO: deeper copying to avoid overwriting problems?
  get_hand_info: -> @_card_info.slice()

  set_attr: (idx, attr, val) ->
    valid_attrs = DISPLAY_ATTRS.concat (k for k of @_attrs)
    assert (attr in valid_attrs), "Invalid attribute #{attr}"

    @_card_info[idx][attr] = val
    if attr in DISPLAY_ATTRS
      @layout()

  set_all: (attr, val) ->
    valid_attrs = DISPLAY_ATTRS.concat (k for k of @_attrs)
    assert (attr in valid_attrs), "Invalid attribute #{attr}"

    for info in @_card_info
      info[attr] = val
    if attr in DISPLAY_ATTRS
      @layout()

  filter: (fn) ->
    ret = []
    for info, idx in @_card_info
      continue if not (fn info)
      tmp = util_m.clone info
      tmp.idx = idx
      ret.push tmp
    return ret

  card_from_coords: (x, y) -> # TODO
    # returns null if no card there

    num_cards = @_card_info.length
    for info, idx in @_card_info.slice().reverse()
      if not (info.drawn_x? and info.drawn_y?)
        continue

      [cx, cy] = [x - info.drawn_x, y - info.drawn_y]
      max_y = @_cg.CARD_HEIGHT
      if info.raised
        # make it so that if you click just under raised card, it
        # still counts as clicking that card and not the one behind it
        max_y += @_raised_ratio * @_cg.CARD_HEIGHT

      if (0 <= cx and cx <= @_cg.CARD_WIDTH and
          0 <= cy and cy <= max_y)
        # TODO: idx or card?
        return num_cards - 1 - idx
    return null

  render: (ctx) ->
    # TODO: have margin
    [x, y] = [0, (@_raised_ratio * @_cg.CARD_HEIGHT)]

    for info, idx in @_card_info
      card = info.card

      if info.invisible
        info.drawn_x = info.drawn_y = null
        continue

      draw_y = y
      if info.raised
        draw_y -= @_raised_ratio * @_cg.CARD_HEIGHT

      if info.glow
        ctx.shadowBlur = 20
        ctx.shadowColor = 'yellow'

      if info.draw?
        info.draw ctx, x, draw_y
      else
        @_cg.draw_card ctx, card, x, draw_y
      info.drawn_x = x # TODO: maybe not the right time to update this
      info.drawn_y = draw_y
      x += @_cg.CARD_WIDTH * @_peek_ratio

      ctx.shadowBlur = null
      ctx.shadowColor = null


class CardArranger
  # Update the CardHand with a new hand while preserving the current
  # ordering of cards. New cards are appended to the end.
  @update_hand = (ch, new_hand, are_equal) ->
    used_indices = new Set()

    hand_idx = 0
    while hand_idx < ch.num_cards()
      attrs = (ch.get_attrs hand_idx)
      remains = false
      for card, idx in new_hand when not used_indices.has(idx)
        if (are_equal card, attrs.card)
          remains = true
          ch.set_attr hand_idx, 'orig_index', idx
          used_indices.add idx
          hand_idx++
          break
      if not remains
        ch.remove hand_idx

    for card, idx in new_hand when not used_indices.has(idx)
      insert_idx = ch.num_cards()
      ch.insert insert_idx, card
      ch.set_attr insert_idx, 'orig_index', idx

  constructor: (@card_hand, @opts) ->
    @opts.on_move ?= (old_idx, new_idx) ->
    @opts.toggle_on_click ?= false
    @_did_move = false
    @_old_raised = null
    @_dragging_idx = null

    # TODO: assert that orig_index exists

    @_on_drag = {
      # TODO: there are probably race conditions here
      start: (idx) =>
        @_dragging_idx = idx
        @_old_raised = (@card_hand.get_attrs idx).raised
        @card_hand.set_attr idx, 'raised', true
      move: (idx) =>
        if idx isnt @_dragging_idx
          old_idx = @_dragging_idx
          @_dragging_idx = idx
          @_did_move = true
          @card_hand.move old_idx, idx
          @opts.on_move old_idx, idx
      end: (idx) =>
        raised = @_old_raised
        if @opts.toggle_on_click and not @_did_move
          raised = not raised

        @card_hand.set_attr @_dragging_idx, 'raised', raised
        @_reset()
    }

  _reset: ->
    @_old_raised = null
    @_dragging_idx = null
    @_did_move = false

  get_selection: ->
    selected = @card_hand.filter (info) ->
      return info.raised
    return selected

  activate: ->
    # TODO: allow multiple drag handlers
    @card_hand.drag @_on_drag
  deactivate: ->
    @card_hand.drag null



class CardSelector
  constructor: (@card_hand, @opts = {}) ->
    @opts.multi_select ?= false

    @card_hand.click (idx) =>
      info = @card_hand.get_attrs idx
      was_raised = (@card_hand.get_attrs idx).raised

      if not @opts.multi_select
        @card_hand.set_all 'raised', false
      @card_hand.set_attr idx, 'raised', (not was_raised)

  get_selection: ->
    selected = @card_hand.filter (info) ->
      return info.raised
    return selected
  # # TODO
  # activate: ->
  # deactivate: ->



exports.HiddenCardHand = HiddenCardHand
exports.CardHand = CardHand
exports.CardArranger = CardArranger
exports.CardSelector = CardSelector