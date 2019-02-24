util_m = require 'shared/util.iced'
{startswith} = util_m
logic = require 'games/tichu/tichu_logic.iced'

test_util_m = require 'games/tichu/logic_tests/test_util'
HA = test_util_m.HandArrays
htsa = test_util_m.hand_to_str_arr


exports.extract = extract = {}

# returns a list of all possible straights
# TODO: disregards suit
extract.straights =
  choices: (hand) ->
    ret = []
    last = null
    cur = []
    for card in hand
      if card.suit in ['dragon', 'dog'] then continue
      if not last?
        last = card
        cur.push card
        continue

      if card.value isnt last.value + 1
        if card.value isnt last.value
          last = card
          cur = [card]
        continue

      last = card
      cur.push card
      if cur.length >= 5
        for i in [0..(cur.length - 5)]
          ret.push cur.slice(i)
    return ret

  precedes: (play1, play2) ->
    info1 = logic.evaluate_hand play1
    info2 = logic.evaluate_hand play2
    if info1.value isnt info2.value
      return info1.value < info2.value
    return play1.length < play2.length

extract.tuples = (n) ->
  choices: (hand) ->
    ret = []
    cards_by_value = ([] for i in [0..14])
    for card in hand
      if card.suit in ['dragon', 'dog'] then continue
      cards_by_value[card.value].push card
    for tuple, val in cards_by_value
      if tuple.length >= n
        ret.push (tuple.slice 0, n)
    return ret

  precedes: (play1, play2) ->
    return play1[0].value < play2[0].value

extract.fullhouses =
  choices: (hand) ->
    ret = []
    cards_by_value = ([] for i in [0..14])
    for card in hand
      if card.suit in ['dragon', 'dog'] then continue
      cards_by_value[card.value].push card

    for tuple1, val1 in cards_by_value
      for tuple2, val2 in cards_by_value
        if val1 is val2 then continue

        if tuple1.length >= 3 and tuple2.length >= 2
          play = tuple1.slice 0, 3
          play = play.concat (tuple2.slice 0, 2)
          play = logic.sorted_by_value play
          ret.push play
    return ret

  precedes: (play1, play2) ->
    info1 = logic.evaluate_hand play1
    info2 = logic.evaluate_hand play2
    return info1.value < info2.value

extract.tractors =
  choices: (hand) ->
    ret = []
    cards_by_value = ([] for i in [0..14])
    for card in hand
      if card.suit in ['dragon', 'dog'] then continue
      cards_by_value[card.value].push card

    streak = []
    for i in [2..14]
      tuple = cards_by_value[i]
      if tuple.length <= 1
        streak = []
        continue
      streak.push (tuple.slice 0, 2)
      if streak.length >= 2
        for i in [0...(streak.length - 1)]
          ret.push (streak.slice i)

    flattened = []
    for play in ret
      flat_play = []
      for pair in play
        flat_play.push pair[0], pair[1]
      flattened.push flat_play
    return flattened

  precedes: (play1, play2) ->
    if play1.length isnt play2.length
      return play1.length < play2.length
    return play1[0].value < play2[0].value


class TichuRecurser
  print = (mesg, plays, hand) ->
    console.log mesg, ((htsa p) for p in plays), 'from', (htsa hand)
  cards_equal = (c1, c2) ->
    return c1.value is c2.value and c1.suit is c2.suit

  MAX_CT = 200000
  constructor: ->
    @_ct = 0

  exclude_cards: (hand, play) ->
    ret = []
    play_idx = 0
    for card, idx in hand
      if (play_idx < play.length and
          cards_equal card, play[play_idx])
        play_idx += 1
      else
        ret.push card
    return ret

  extract_recursively: (plays_so_far, hand,
                        extractor, next) ->
    filtered_plays = []
    try
      choices = extractor.choices hand
    catch e
      console.log "Failed to extract", hand
      throw e

    for play in choices
      is_new = true
      for played in plays_so_far
        if extractor.precedes play, played
          is_new = false
          break
      if is_new
        filtered_plays.push play

    for play in filtered_plays
      remaining = @exclude_cards hand, play
      plays_now = plays_so_far.concat [play]
      @extract_recursively plays_now, remaining,
        extractor, next

      if @_ct > MAX_CT
        console.warn "Recursion exceeded #{MAX_CT} possibilities, giving up!"
        return

    next plays_so_far, hand


  chain_extract: (hand, extractors, on_extract) ->
    @_ct = 0

    do_extract = (plays_so_far, hand_left, idx) =>
      if idx >= extractors.length
        @_ct++
        return on_extract plays_so_far, hand_left

      @extract_recursively [], hand_left,
        extractors[idx], (extracted_plays, hl) ->
          plays_now = plays_so_far.concat extracted_plays
          do_extract plays_now, hl, (idx + 1)

    do_extract [], hand, 0



exports.TichuRecurser = TichuRecurser