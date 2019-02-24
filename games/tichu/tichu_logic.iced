assert = require 'assert'

# cards have a suit (string) and value (integer/float)
SUITS = ['C', 'D', 'H', 'S']
SPECIAL_CARDS = ['phoenix', 'dragon', 'mahjong', 'dog']

# Enum for tichu states
exports.CAN_GRAND = 0
exports.CAN_TICHU = 1
exports.GRAND = 2
exports.TICHU = 3
exports.NO_TICHU = 4

exports.make_deck = make_deck = ->
  deck = []
  for suit in ['C', 'D', 'H', 'S']
    for value in [2..14]
      deck.push {suit: suit, value: value}
  deck.push {suit: 'mahjong', value: 1}
  deck.push {suit: 'dog', value: 0}
  deck.push {suit: 'dragon', value: 17}
  deck.push {suit: 'phoenix', value: 16}
  return deck

exports.is_points = is_points = (card) ->
  return (points_value [card]) isnt 0

exports.points_value = points_value = (hand) ->
  ret = 0
  for card in hand
    if card.suit is 'dragon'
      ret += 25
    else if card.suit is 'phoenix'
      ret -= 25
    else if card.value is 13
      ret += 10
    else if card.value in [5, 10]
      ret += card.value
  return ret

exports.points_value_of_trick = points_value_of_trick = (trick) ->
    ret = 0
    for hand in trick
        ret += points_value(hand)
    return ret

# Sort by value then suit, with phoenix as largest suit
exports.comparator = comparator = (a,b) ->
  if a.value == b.value
    if a.suit == b.suit
      return 0
    if a.suit == 'phoenix'
      return 1
    if b.suit == 'phoenix'
      return -1
    return if a.suit > b.suit then 1 else -1
  return a.value - b.value

# NOT in place
exports.sorted_by_value = sorted_by_value = (hand) ->
  ret = hand.slice()
  return ret.sort comparator

num_of_suit = (hand, suit) ->
  total = 0
  for card in hand
    if card.suit == suit
      total += 1
  return total

num_phoenixes = (hand) ->
  total = num_of_suit hand, 'phoenix'
  assert total <= 1
  return total

num_dogs = (hand) ->
  total = num_of_suit hand, 'dog'
  assert total <= 1
  return total

num_dragons = (hand) ->
  total = num_of_suit hand, 'dragon'
  assert total <= 1
  return total

hand_is_phoenix = (hand) ->
  if hand.length != 1
    return false
  return hand[0].suit == 'phoenix'

###
# Hand evaluation and classification
###

# returns obj with type, value field
# types of hands: tuple[1-3] straight[5-14]
# fullhouse, tractor[2-7], bomb, and dog (no value field)
# Assumes that phoenix has been given its value.
#
# instead returns null if hand is invalid
exports.evaluate_hand = evaluate_hand = (hand) ->
  hand = sorted_by_value hand

  if hand.length == 0
    # console.log 'asked to evaluate empty hand'
    return null

  # check that dog / dragon are only in singletons
  if num_dogs(hand) >= 1 or num_dragons(hand) >= 1
    if hand.length != 1
      return null

  # try to match this hand to some type
  for type_fn in [dog_info, bomb_info, tuple_info, fh_info, straight_info, tractor_info]
    attempt = type_fn hand
    if attempt? then return attempt

  return null

###
# The following info methods assume hand is sorted by value.
# They check if the given hand meets the type.
# If it does, it returns an obj with type and value fields.
# If it doesn't, it returns null.
###
dog_info = (hand) ->
  if hand.length != 1 then return null
  if hand[0].suit == 'dog'
    return {
      type: 'DOG'
    }
  return null

bomb_info = (hand) ->
  if hand.length < 4 then return null

  # no phoenixes allowed
  if num_phoenixes(hand) > 0 then return null

  if (ti = tuple_info hand)?
    return {
      type: 'BOMB'
      value: ti.value
    }
  if (si = straight_info hand)?
    # test for flush
    suit = hand[0].suit
    for card in hand
      if card.suit != suit
        return null
    return {
      type: 'BOMB'
      value: si.value + 100 * hand.length # longer ones win
    }
  return null

tuple_info = (hand) ->
  if hand.length == 0 then return null
  n = hand.length

  # Special case for n=4 (bomb): no phoenix
  if n >= 4 and num_phoenixes(hand) > 0
    return null

  val = hand[0].value
  for card in hand
    if val != card.value
      return null

  return {
    type: 'TUPLE' + n
    value: val
  }

fh_info = (hand) ->
  unless hand.length == 5 then return null
  if tuple_info(hand.slice 0, 3)? and tuple_info(hand.slice 3, 5)?
    return {
      type: 'FULLHOUSE'
      value: hand[2].value
    }
  if tuple_info(hand.slice 0, 2)? and tuple_info(hand.slice 2, 5)?
    return {
      type: 'FULLHOUSE'
      value: hand[2].value
    }
  return null

straight_info = (hand) ->
  if hand.length < 5 then return null
  min_val = hand[0].value
  unless 1 <= min_val <= 14
    return null
  for i in [1...hand.length]
    if hand[i].value != min_val + i
      return null
  unless 1 <= min_val + hand.length - 1 <= 14
    return null
  return {
    type: 'STRAIGHT' + hand.length
    value: min_val
  }

tractor_info = (hand) ->
  m = hand.length
  if m <= 2 or m % 2 != 0
    return null
  n = m / 2

  min_val = hand[0].value
  unless 2 <= min_val <= 14
    return null
  for i in [0...n]
    if hand[2*i].value != hand[2*i+1].value
      return null
    if hand[2*i].value != min_val + i
      return null
  unless 2 <= min_val + n - 1 <= 14
    return null
  return {
    type: 'TRACTOR' + n
    value: min_val
  }

##
# functions no longer assume sorted input

exports.is_bomb = is_bomb = (hand) ->
  hand = sorted_by_value hand
  return (bomb_info hand)?

# assumes any phoenixes have their value written
# (even for case of phoenix played as single)
# for case of phoenix as single, assumes integer value (rounded down)
# a phoenixed value beats a nonphoenixed same value
exports.is_playable_over = is_playable_over = (hand, other_hand) ->
  hand_info = evaluate_hand hand
  # console.log 'new_hand', hand_info

  if not hand_info?
    return false

  if not other_hand? or other_hand.length == 0
    # if phoenix, value must be 1.5
    if hand_is_phoenix(hand)
      return hand[0].value == 1
    # otherwise, hand is a legal non-phoenix play, and this is a lead
    return true

  other_hand_info = evaluate_hand other_hand

  if not other_hand_info?
    console.log 'WARNING: invalid old hand in is_playable_over'
    return false

  # console.log 'old_hand', other_hand_info

  # Dog can't be played over, not even by bomb

  if other_hand_info.type == 'DOG'
    return false

  # All bombs beat all non-dog nonbombs
  if hand_info.type == 'BOMB' and other_hand_info.type != 'BOMB'
    return true

  # Dragon can't be beaten by nonbombs (looking at you phoenix)
  if other_hand_info.type == 'TUPLE1' and other_hand[0].suit == 'dragon'
    return false

  # Single phoenix can only beat previous by exactly 0, b/c of rounding
  if hand_is_phoenix(hand) and other_hand_info.type == 'TUPLE1'
    return hand[0].value - other_hand[0].value == 0

  return (hand_info.type == other_hand_info.type and
    hand_info.value > other_hand_info.value)

exports.does_satisfy_mahjong_wish = does_satisfy_mahjong_wish = (hand, mahjong_wish) ->
  unless mahjong_wish?
    return false
  unless 2 <= mahjong_wish <= 14
    return false
  for card in hand
    if card.value == mahjong_wish and card.suit != 'phoenix'
      return true
  return false

# returns array of all possible phoenix values
# that would complete this hand
# assumes phoenix is in this hand
# for case of phoenix as single, assumes integer value (rounded down)
# a phoenixed value beats a nonphoenixed same value
exports.valid_phoenix_values = valid_phoenix_values = (hand, last_hand) ->
  for card, i in hand
    if card.suit == 'phoenix'
      phoenix_idx = i
      break
  unless phoenix_idx?
    throw new Error 'no phoenix in sight!'

  # phoenix as singleton
  if hand.length == 1
    # as lead
    if (not last_hand?) or last_hand.length == 0
      return [1]
    # over previous, must be singleton
    if last_hand.length != 1
      return []
    # not allowed to be played over dragon or dog
    if num_dogs(last_hand) >= 1 or num_dragons(last_hand) >= 1
      return []
    return [last_hand[0].value]

  hand = hand.slice()

  valid_values = []

  for i in [2..14]
    hand[phoenix_idx] = {suit: 'phoenix', value: i}
    if is_playable_over hand, last_hand
      valid_values.push i

  return valid_values


# # copies the value and suit attributes only
# deepcopy_hand = (hand) ->
#   return ({value: card.value, suit: card.suit} for card in hand)

# utility helper to tell if type string starts with given substr
starts_with = (type, substr) ->
  type.lastIndexOf(substr, 0) == 0

can_satisfy_mahjong_wish = (prev_hand, entire_hand, wish) ->
  unless wish?
    return false
  unless 2 <= wish <= 14
    return false

  all_info = full_hand_info entire_hand
  hand_values = all_info.values
  phoenixes = all_info.phoenixes

  # can't satisfy wish if the wish card isn't present
  unless hand_values[wish] > 0
    return false

  # Lead and having wish card means you can fulfill
  if (not prev_hand?) or prev_hand.length == 0
    return true

  prev_hand_eval = evaluate_hand prev_hand

  # previous hand should be legal...
  unless prev_hand_eval?
    console.log 'WARNING: illegal previous hand for mahjong wish'
    return false

  # you can't play over the dog
  prev_type = prev_hand_eval.type
  if prev_type == 'DOG'
    return false

  # do you have a bomb with the wish value?
  best_bomb = get_best_bomb all_info, wish
  if best_bomb?
    # if so, you can play iff this bomb can play
    return is_playable_over best_bomb, prev_hand

  # code assumes your hand has no bombs (with the wish val)
  if prev_type == 'BOMB'
    return false

  # casework by type
  if starts_with prev_type, 'TUPLE'
    return wish > prev_hand_eval.value and
           phoenixes + hand_values[wish] >= prev_hand.length

  if starts_with prev_type, 'STRAIGHT'
    prev_min = prev_hand_eval.value
    len = prev_hand.length
    return has_straight_over all_info, wish, prev_min, len

  if starts_with prev_type, 'TRACTOR'
    prev_min = prev_hand_eval.value
    len = prev_hand.length
    return has_tractor_over all_info, wish, prev_min, len

  if prev_type == 'FULLHOUSE'
    trip = prev_hand_eval.value
    return has_fh_over all_info, wish, trip

exports.can_satisfy_mahjong_wish = can_satisfy_mahjong_wish

# returns object with info about this hand
# values: array with number of cards with each value 1-14
# phoenixes: integer equal to number of phoenixes in hand
# hand_set: set of nonspecial cards in this hand
# hand: the original hand
full_hand_info = (hand) ->
  values = (0 for i in [0..14])
  phoenixes = 0
  hand_set = {}
  for card in hand
    if card.suit == 'phoenix'
      phoenixes += 1
    else if card.suit in ['dragon', 'dog']
      continue
    else if card.suit == 'mahjong'
      values[1] += 1
    # not special card
    else
      values[card.value] += 1
      hand_set[card_hash card] = true

  return {
    values: values
    phoenixes: phoenixes
    hand: hand
    hand_set: hand_set
  }

# only meant for use with non-special cards
card_hash = (card) -> card.value + card.suit

# does set contain this card?
contains_card = (hand_set, card) -> (card_hash card) of hand_set

# does set contain this card (specified by values given)?
contains = (hand_set, value, suit) -> (value + suit) of hand_set

# returns the best bomb in this hand, specified by all_info,
# containing a card of the given value.
# returns null if none found
get_best_bomb = (all_info, val) ->
  # first check for straight flushes
  hs = all_info.hand_set
  best_min = 0
  best_len = 4
  best_suit = null
  for suit in SUITS
    # is the wish val even there?
    unless contains hs, val, suit
      continue
    amt_above = 0
    for i in [(val+1)..14]
      if contains hs, i, suit
        amt_above += 1
      else
        break
    amt_below = 0
    for i in [(val-1)..2]
      if contains hs, i, suit
        amt_below += 1
      else
        break
    straight_len = amt_below + amt_above + 1
    # see if this straight is better
    if straight_len < 5
      continue

    new_min = val - amt_below
    if straight_len > best_len or
       straight_len == best_len and new_min > best_min
      best_min = new_min
      best_len = straight_len
      best_suit = suit

  # did we find a straight flush?
  if best_suit?
    return build_straight_flush best_min, best_len, best_suit

  # otherwise, 4 of a kind?
  if all_info.values[val] >= 4
    return build_4bomb val

  # no bombs here
  return null
# utility to build straight flush given min, length, suit
build_straight_flush = (min, len, suit) ->
  hand = []
  for val in [min...(min+len)]
    hand.push {value: val, suit: suit}
  return hand

# utility to build 4 of a kind bomb given value
build_4bomb = (val) -> ({value: val, suit: s} for s in SUITS)

# Determine if hand can play a straight with given wish card
# over a straight of given min value and length
has_straight_over = (all_info, wish, min, len) ->
  for i in [(min+1)..14]
    # is this i even a legal minimum for straight of this len?
    if i + len > 14
      continue
    # does this range even have the wish card?
    unless i <= wish < i + len
      continue
    if has_straight_equal all_info, i, len
      return true
  return false

has_straight_equal = (all_info, min, len) ->
  p_needed = 0
  p_have = all_info.phoenixes
  values = all_info.values
  for i in [min...(min+len)]
    if values[i] == 0
      p_needed += 1
      if p_needed > p_have
        return false
  return true


# Determine if hand can play a tractor with given wish card
# over a tractor of given min value and length
has_tractor_over = (all_info, wish, min, len) ->
  for i in [(min+1)..14]
    # is this i even a legal minimum for tractor of this len?
    if i + len > 14
      continue
    # does this range even have the wish card?
    unless i <= wish < i + len
      continue
    if has_tractor_equal all_info, i, len
      return true
  return false


has_tractor_equal = (all_info, min, len) ->
  p_needed = 0
  p_have = all_info.phoenixes
  values = all_info.values
  for i in [min...(min+len)]
    if values[i] < 2
      p_needed += 2 - values[i]
      if p_needed > p_have
        return false
  return true

# Determine if hand can play a fullhouse with given wish card
# over a fullhouse of given trip value
has_fh_over = (all_info, wish, trip) ->
  if wish > trip
    # wish can be the triple
    for i in [2..14]
      if has_fh_equal all_info, wish, i
        return true
  # wish can be the pair
  for i in [(trip+1)..14]
    if has_fh_equal all_info, i, wish
      return true
  return false

has_fh_equal = (all_info, trip, pair) ->
  if trip == pair
    return false
  num_phx = all_info.phoenixes
  values = all_info.values

  useable_triples = Math.min(3, values[trip])
  useable_pairs = Math.min(2, values[pair])

  return useable_pairs + useable_triples + num_phx >= 5
