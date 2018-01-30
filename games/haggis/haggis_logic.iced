assert = require 'assert'
util_m = require 'shared/util.iced'

PLAIN_SUITS = 'ABCD'
FACE_SUITS = 'JQK'
ALL_SUITS = PLAIN_SUITS + FACE_SUITS

exports.make_deck = make_deck = ->
  deck = []
  for suit in PLAIN_SUITS
    for value in [2..10]
      deck.push {suit: suit, value: value}
  return deck

exports.make_wilds = make_wilds = ->
  ret = []
  for suit in FACE_SUITS
    ret.push {suit: suit, value: 0}
  return ret

exports.sorted_by_value = sorted_by_value = (hand) ->
  by_value = (a, b) ->
    if a.value isnt b.value
      return a.value - b.value
    return ('ABCDJQK'.indexOf a.suit) - ('ABCDJQK'.indexOf b.suit)
  return (hand.slice().sort by_value)

exports.points_value = points_value = (cards) ->
  face_values = {J: 2, Q: 3, K: 5}
  ret = 0
  for card in cards
    if card.suit of face_values
      ret += face_values[card.suit]
    else if card.value % 2 == 1
      ret += 1
  return ret

exports.is_wild = is_wild = (card) ->
  return card.suit in FACE_SUITS

# assumes wild cards have been assigned values
exports.evaluate_sequence = evaluate_sequence = (hand) ->
  if hand.length is 1
    return {type: "SEQ1:1", value: hand[0].value}

  mult = 1
  while mult < hand.length and hand[mult].value is hand[0].value
    mult += 1
  if hand.length % mult isnt 0 then return null

  len = hand.length / mult
  if mult is 1 and len < 3 then return null

  start = hand[0].value
  suits = new Set()
  for i in [0...len]
    for j in [0...mult]
      card = hand[i * mult + j]
      if card.value isnt start + i
        return null
      suits.add card.suit

  for suit in FACE_SUITS
    suits.delete suit
  if suits.size > mult then return null

  return {
    type: "SEQ#{mult}:#{len}"
    value: start
  }

exports.evaluate_face_bomb = evaluate_face_bomb = (hand) ->
  for c in hand
    # To play face cards as a bomb, the value must be set to
    # zero. This allows us to disambiguate between JQK as a bomb or as
    # a sequence.
    if c.value isnt 0 then return null
  for combo, i in ['JQ', 'QK', 'JK', 'JQK']
    if hand.length isnt combo.length
      continue
    for suit, j in combo
      if hand[j].suit isnt suit then return null
    return {type: "BOMB", value: i + 1}
  return null

exports.evaluate_odds_bomb = evaluate_odds_bomb = (hand) ->
  if hand.length isnt 4 then return null
  for val, i in [3, 5, 7, 9]
    if hand[i].value isnt val then return null
  suits = new Set()
  for c in hand
    suits.add c.suit
  if suits.size is 4
    return {type: "BOMB", value: 0}
  if suits.size is 1
    return {type: "BOMB", value: 5}
  return null

exports.evaluate_hand = evaluate_hand = (hand) ->
  hand = sorted_by_value hand
  if hand.length == 0 then return null
  return (evaluate_face_bomb hand) or
         (evaluate_odds_bomb hand) or
         (evaluate_sequence hand) or null

exports.is_playable_over = is_playable_over = (hand, other_hand) ->
  hand_info = evaluate_hand hand
  if not hand_info? then return false

  # Any valid hand can be a lead.
  if not other_hand? then return true

  other_info = evaluate_hand other_hand
  if hand_info.type is 'BOMB'
    return (other_info.type isnt 'BOMB') or (other_info.value < hand_info.value)
  return (hand_info.type is other_info.type) and (other_info.value < hand_info.value)

all_value_mappings = (wilds, min_val = 2) ->
  if wilds.length is 0 then return [[]]
  ret = []
  vals = [min_val..10]
  vals.push {J: 11, Q: 12, K: 13}[wilds[0]]
  for val in vals
    for mapping in (all_value_mappings wilds.slice(1), val)
      ret.push [val].concat(mapping)
  return ret

exports.display_string = display_string = (hand) ->
  hand = sorted_by_value hand
  evaluation = evaluate_hand hand
  assert evaluation?
  if evaluation.type is 'BOMB'
    if evaluation.value is 0
      return "3 5 7 9 (melange)"
    if evaluation.value is 5
      return "3 5 7 9 (suited)"
    return (c.suit for c in hand).join(' ')

  ret = []
  for card in hand
    if is_wild card
      ret.push (card.suit + '(' + card.value + ')')
    else
      ret.push ('' + card.value)
  return ret.join(' ')

# Given a hand, returns all legal value mappings for the face cards.
exports.valid_wild_values = (hand, prev_hand) ->
  wilds = []
  wild_idxs = []
  for face in FACE_SUITS
    for card, idx in hand
      if card.suit is face
        wilds.push face
        wild_idxs.push idx
        break

  possible_hand = util_m.clone hand
  ret = []
  if hand.length is wilds.length
    # Consider playing as a bomb.
    for c in possible_hand
      c.value = 0
    if (is_playable_over possible_hand, prev_hand)
      ret.push {
        values: (0 for _ in possible_hand)
        display_string: display_string possible_hand
      }

  # Consider all non-bomb ways of playing the face cards.
  for mapping in (all_value_mappings wilds)
    wild_vals = (null for _ in hand)
    for idx, j in wild_idxs
      possible_hand[idx].value = mapping[j]
      wild_vals[idx] = mapping[j]
    if (is_playable_over possible_hand, prev_hand)
      ret.push {
        values: wild_vals
        display_string: display_string possible_hand
      }
  return ret
