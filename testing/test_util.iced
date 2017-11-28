assert = require 'assert'
readline = require 'readline'
util_m = require 'shared/util.iced'

exports.rand_int = rand_int = (n) ->
  return Math.floor (Math.random() * n)

class CardGenerator
  VAL_STR = [null, null].concat (i.toString() for i in [2..10])
  VAL_STR = VAL_STR.concat ['J', 'Q', 'K', 'A']

  constructor: (@specials = {}) ->

  deck: ->
    ret = []
    for suit in ['C', 'D', 'H', 'S']
      for value in [2..14]
        ret.push {suit, value}
    for _, c of @specials
      ret.push (util_m.clone c)
    return ret

  to_str: (card) ->
    for name, c of @specials
      if card.value is c.value and card.suit is c.suit
        return name
    return VAL_STR[card.value] + card.suit

  from_str: (s) ->
    s = s.toUpperCase()
    if @specials[s]?
      return util_m.clone @specials[s]

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

class HandGenerator
  pick_random_k = (l, k) ->
    assert l.length >= k
    num_left = k
    ret = []
    for item, idx in l
      if Math.random() < (num_left / (l.length - idx))
        ret.push item
        num_left--
    return ret

  constructor: (@card_gen) ->
    @_cur_deck = @card_gen.deck()

  reset: ->
    @_cur_deck = @card_gen.deck()

  draw_n: (n, filter = null) ->
    filter ?= -> true
    assert (n <= @_cur_deck.length)

    tries = 0

    hand = []
    while hand.length < n
      if tries > 5 * @_cur_deck.length
        throw new Error """
          No valid draw after #{tries} tries, likely impossible!
        """

      idx = rand_int @_cur_deck.length
      [card] = @_cur_deck.splice idx, 1
      if filter card
        hand.push card
      tries += 1
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

exports.CardGenerator = CardGenerator
exports.HandGenerator = HandGenerator
exports.InteractiveTester = InteractiveTester
