assert = require 'assert'
readline = require 'readline'
tichu_logic_m = require '../tichu_logic.iced'

exports.rand_int = rand_int = (n) ->
  return Math.floor (Math.random() * n)

exports.make_card_str = make_card_str = (card) ->
  if card.suit in ['phoenix', 'dog', 'dragon', 'mahjong']
    return card.suit
  else
    return card.value + card.suit # value, then suit

exports.hand_to_str_arr = hand_to_str_arr = (hand) ->
  return (make_card_str card for card in hand)


exports.make_card = make_card = (s) ->
  s = s.toUpperCase()
  if s == 'DOG'
    return {suit: 'dog', value: 0.5}
  if s == 'MAHJONG'
    return {suit: 'mahjong', value: 1}
  if s == 'DRAGON'
    return {suit: 'dragon', value: 16}
  if s == 'PHOENIX' or s == 'P' # TODO: specify value
    return {suit: 'phoenix', value: -1}

  len = s.length
  suit = s.slice (len - 1), len

  value_str = s.slice 0, len - 1
  value = switch value_str
    when 'A' then 14
    when 'K' then 13
    when 'Q' then 12
    when 'J' then 11
    else parseInt value_str, 10
  return {suit: suit, value: value}

exports.make_hand = make_hand = (raw_card_list) ->
  hand = ((make_card s) for s in raw_card_list)
  hand.sort tichu_logic_m.comparator
  return hand

SUITS = 'CDHS'

class HandArrays
  ###
  # The following functions return an array of strings
  # of a hand representing the given play.
  # make_hand can be called to turn this into a hand.
  ###
  @bomb = (val) ->
    return ((val + suit) for suit in SUITS)

  # TODO: vary the suits?

  @tuple = (val, n) ->
    return ((val + SUITS[i]) for i in [0...n])

  @single = (val) -> @tuple(val, 1)
  @pair = (val) -> @tuple(val, 2)
  @triple = (val) -> @tuple(val, 3)

  @tractor = (val, len) ->
    result = []
    for i in [val...(val+len)]
      result.push (i + SUITS[0])
      result.push (i + SUITS[3])
    return result

  @fh = (trip, pair) ->
    result = []
    for i in [0,3,2]
      result.push (trip + SUITS[i])
    for i in [1,3]
      result.push (pair + SUITS[i])
    return result

  @straight = (val, len) ->
    return (i + SUITS[i % 4] for i in [val...(val+len)])

  @straight_flush = (val, len, suit='C') ->
    return (i + suit for i in [val...(val+len)])

class HandGenerator
  ALL_CARDS = ['phoenix', 'dog', 'dragon', 'mahjong']
  for i in [2..14]
    for c in SUITS
      ALL_CARDS.push (i + c)

  pick_random_k = (l, k) ->
    assert l.length >= k
    num_left = k
    ret = []
    for item, idx in l
      if Math.random() < (num_left / (l.length - idx))
        ret.push item
        num_left--
    return ret

  @draw_n = (n, excluding = []) ->
    assert (n + excluding.length <= ALL_CARDS.length)
    excluding = ((make_card_str c) for c in excluding)

    hand = []
    while hand.length < n
      idx = rand_int ALL_CARDS.length
      card = ALL_CARDS[idx]
      if card in hand or card in excluding
        continue
      hand.push card
    return make_hand hand

  @draw_ntuple = (n) ->
    assert n <= 4
    k = 2 + (rand_int 13)
    k_cards = []
    for c in ALL_CARDS
      if (make_card c).value == k
        k_cards.push c
    ntuple = pick_random_k k_cards, n
    return make_hand ntuple

  @draw_random_fullhouse = ->
    # TODO: include phoenix?
    n = m = null
    while n is m
      n = 2 + (rand_int 13)
      m = 2 + (rand_int 13)
    [n_cards, m_cards] = [[], []]
    for c in ALL_CARDS
      if (make_card c).value == n
        n_cards.push c
      if (make_card c).value == m
        m_cards.push c

    trips = pick_random_k n_cards, 3
    pair = pick_random_k m_cards, 2
    return make_hand (trips.concat pair)

  @draw_random_play = (type = null) ->
    n = 1 + (rand_int 6)

    while true
      hand = @draw_n n
      type_info = tichu_logic_m.evaluate_hand hand
      if type_info is null
        continue

      if type is null or type_info.type is type
        return hand


class InteractiveTester
  constructor: (@display_fn) ->
    @_bad_cases = []
    @_rl = readline.createInterface {
      input: process.stdin
      output: process.stdout
    }

  run_loop: ->
    case_data = @display_fn()
    @_rl.question 'Hit enter if correct, type n if wrong: ', (answer) =>
      answer = answer.trim()
      if answer isnt ''
        console.log 'Bad case recorded.'
        case_data.result = not case_data.result
        @_bad_cases.push case_data
      @run_loop()

  run: ->
    process.on 'exit', =>
      console.log '\nBad cases encountered:\n\n'
      console.log (JSON.stringify @_bad_cases)
      console.log '\n\n'
    @run_loop()

exports.HandArrays = HandArrays
exports.HandGenerator = HandGenerator
exports.InteractiveTester = InteractiveTester


