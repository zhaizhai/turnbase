assert = require 'assert'
util_m = require 'shared/util.iced'
{V} = require 'shared/T/validation.iced'


exports.by_suit = by_suit = (ctx) ->
  SUIT_RANK = {
    C: 0, D: 1, H: 2, S: 3, trump: 4
  }
  return (a, b) ->
    suit_a = SUIT_RANK[get_suit a, ctx]
    suit_b = SUIT_RANK[get_suit b, ctx]
    if suit_a isnt suit_b
      return suit_a - suit_b
    if suit_a isnt SUIT_RANK['trump']
      return a.value - b.value
    return (trump_value a, ctx) - (trump_value b, ctx)

winner_idx = (trick, ctx) ->
  ret = 0
  for play, idx in trick
    if is_greater play, trick[ret], ctx
      ret = idx
  return ret

gather_points = (cards) ->
  pts = 0
  for c in cards
    switch c.value
      when 5 then pts += 5
      when 10 then pts += 10
      when 13 then pts += 10
  return pts

# TODO: account for multiplay leads
validate_lead = (cards, ctx) ->
  if cards.length > 1
    throw new Error "TODO: can't handle multiplays yet"
  return V.r true

validate_play = (lead, cards, hand, ctx) ->
  lead_suit = get_suit lead[0], ctx

  matching_indices = []
  for c, idx in hand
    if (get_suit c, ctx) is lead_suit
      matching_indices.push idx

  if matching_indices.length <= lead.length
    for idx in matching_indices
      if idx not in cards
        return V.r false, "Must follow suit"
    return V.r true

  for idx in cards
    if idx not in matching_indices
      return V.r false, "Must follow suit"
  return V.r true


exports.get_suit = get_suit = (card, ctx) ->
  if (trump_value card, ctx) > 0
    return 'trump'
  return card.suit


trump_value = (card, ctx) ->
  # 2 through 14 are normal cards
  # 15-16 are numbered cards
  # 17, 18 are joker

  JOKER_BASELINE = 17
  if card.suit is 'joker'
    return JOKER_BASELINE + card.value

  LEVEL_BASELINE = 15
  if card.value is ctx.trump_value
    ret = LEVEL_BASELINE
    if card.suit is ctx.trump_suit
      ret += 1
    return ret

  if card.suit is ctx.trump_suit
    return card.value
  return 0


is_greater = (cards1, cards2, ctx) ->
  assert cards1.length is cards2.length
  len = cards1.length

  is_trump1 = util_m.all ((trump_value c, ctx) > 0 for c in cards1)
  is_trump2 = util_m.all ((trump_value c, ctx) > 0 for c in cards2)

  if is_trump1 isnt is_trump2
    return is_trump1

  if is_trump1 and is_trump2
    val1 = trump_value cards1[len - 1], ctx
    val2 = trump_value cards2[len - 1], ctx
    return val1 > val2

  for i in [0...len]
    # TODO: assumes cards2 are all same suit
    if cards1[i].suit isnt cards2[0].suit
      return false

  return cards1[len - 1].value > cards2[len - 1].value

exports.winner_idx = winner_idx
exports.gather_points = gather_points
exports.validate_play = validate_play
exports.validate_lead = validate_lead