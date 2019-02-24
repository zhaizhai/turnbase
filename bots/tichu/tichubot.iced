util_m = require 'shared/util.iced'
{startswith} = util_m
logic = require 'games/tichu/tichu_logic.iced'

test_util_m = require 'games/tichu/logic_tests/test_util'
HA = test_util_m.HandArrays
htsa = test_util_m.hand_to_str_arr

{TichuRecurser, extract} = require 'bots/tichu/plan_recurse.iced'
{PlanEvaluator} = require 'bots/tichu/plan_evaluator.iced'
{CardCounter} = require 'bots/tichu/card_counter.iced'

combinations = (n, k) ->
  if k > n
    return []

  cur = [0...k]
  ret = [[0...k]]
  while true
    inc_idx = k - 1;
    while inc_idx >= 0 and cur[inc_idx] is n - k + inc_idx
      inc_idx -= 1

    if inc_idx < 0 # no more combinations
      break

    cur[inc_idx] += 1
    for i in [(inc_idx + 1)...k]
      cur[i] = cur[i - 1] + 1
    ret.push cur.slice()
  return ret

bot_action = (gc, cmd, args, delay) ->
  await setTimeout defer(), delay
  await gc.submit_action cmd, args, defer err, res
  console.log err, res

class GrandTichuHandler
  constructor: (@gc, @player_id) ->
  init: ->
    player = @gc.state().players[@player_id]
    if player.num_cards() is 8
      bot_action @gc, 'next_cards', [], 300
  action: ->
  cleanup: ->

class PassHandler
  get_best = (choices, evaluate) ->
    best = null
    for choice in choices
      item = evaluate choice
      if not best? or item.value > best.value
        best = item
    return best

  constructor: (@gc, @player_id) ->
    @evaluator = new PlanEvaluator()

  _phx_idx: ->
    player = @gc.state().players[@player_id]
    for card, idx in player.cards
      if card.suit is 'phoenix'
        return idx
    return null

  init: ->
    if @gc.state().to_pass[@player_id]?
      return

    player = @gc.state().players[@player_id]
    cards = ({suit: c.suit, value: c.value} for c in player.cards)
    idx = @_phx_idx()
    phx = if idx? then cards[idx] else null
    phx?.value = 14 # TODO: hard-coded for now

    combos = combinations cards.length, 3
    best_pass = get_best combos, (to_pass) =>
      remaining = []
      for c, i in cards
        if i not in to_pass
          remaining.push c
      best = @evaluator.consider_all_plans remaining
      return {pass: to_pass, value: best.value}

    # TODO: give best card to partner
    bot_action @gc, 'pass', [best_pass.pass], 300
  action: ->
  cleanup: ->

class PlayHandler
  constructor: (@gc, @player_id) ->
    @evaluator = new PlanEvaluator()
    @partner_id = (@player_id + 2) % 4
    @card_counter = new CardCounter

  _phx_idx: ->
    player = @gc.state().players[@player_id]
    for card, idx in player.cards
      if card.suit is 'phoenix'
        return idx
    return null

  _my_cards: ->
    player = @gc.state().players[@player_id]
    cards = ({suit: c.suit, value: c.value} for c in player.cards)
    idx = @_phx_idx()
    phx = if idx? then cards[idx] else null
    phx?.value = 14 # TODO: hard-coded for now
    return {cards, phx}

  _distort: (v) ->
    if v > 0
      return v * 0.9
    else
      return v * 1.1

  _do_lead_play: ->
    # TODO: doesn't handle the case where there is an outstanding
    # mahjong wish
    {cards, phx} = @_my_cards()
    # TODO: consider all possible values of phoenix
    best = @evaluator.consider_all_plans cards
    worst = null

    for play in best.item
      value = @evaluator.evaluate_play play
      if best.value > 0.1 # try to clear out cards
        value -= play.length / 7
      if not worst? or value < worst.value
        worst = {play, value}

    get_idx = (c) ->
      for card, idx in cards
        if card.suit is c.suit and card.value is c.value
          return idx
      throw new Error "Invalid card #{JSON.stringify c}"

    to_play = []
    for pcard in worst.play
      to_play.push (get_idx pcard)
    # TODO: account for other phx values
    phx_val = 14
    if to_play.length is 1 and cards[to_play[0]].suit is 'phoenix'
      phx_val = 1
    bot_action @gc, 'play', [to_play, phx_val, null], 800

  _consider_play: ->
    if @gc.state().cur_turn isnt @player_id
      return

    last_play = @gc.state().cur_trick.last_play()
    if not last_play?
      # our lead!
      return @_do_lead_play()

    {cards, phx} = @_my_cards()
    possibilities = []

    if (@gc.is_valid 'pass', [])
      best = @evaluator.consider_all_plans cards
      possibilities.push {
        play: []
        value: (@_distort best.value)
      }

    compute_possibility = (cards, play_idxs, play, phx_val) =>
      # slightly hacky way to set phx value to evaluate properly
      phx?.value = phx_val

      play_bonus = @evaluator.evaluate_play play
      # don't play over partner
      if play_bonus >= 0 and @gc.state().last_player is @partner_id
        return {play: play_idxs, value: -100, phx: phx_val}
      play_bonus = Math.max 0, play_bonus

      remaining = []
      for c, i in cards
        if i not in play_idxs
          remaining.push c
      best = @evaluator.consider_all_plans remaining
      return {
        play: play_idxs
        value: play_bonus + (@_distort best.value)
        phx: phx_val
      }

    combos = combinations cards.length, last_play.length
    for play_idxs in combos
      play = (cards[i] for i in play_idxs)
      for phx_val in [1..14]
        if not @gc.is_valid 'play', [play_idxs, phx_val, null]
          continue

        # console.log 'Considering play', (htsa play), 'on', (htsa last_play)
        poss = compute_possibility cards, play_idxs, play, phx_val
        possibilities.push poss

    best_choice = possibilities[0]
    for choice in possibilities
      if choice.value > best_choice.value
        best_choice = choice

    if best_choice.play.length is 0
      bot_action @gc, 'pass', [], 800
    else
      console.log 'making play:', best_choice.play
      console.log 'phx value:', best_choice.phx
      console.log (cards[i] for i in best_choice.play)
      bot_action @gc, 'play',
        [best_choice.play, best_choice.phx, null], 800

  init: ->
    @_consider_play()
  action: (data) ->
    if data.extra?.played_dog
      @card_counter.track_play [{suit: 'dog', value: 0}]
    @card_counter.track_play @gc.state().cur_trick.last_play()

    # TODO: check if we're in 1v1 mode, if so use 1v1 logic

    @_consider_play()
  cleanup: ->

class PickDragonHandler
  constructor: (@gc, @player_id) ->
  init: ->
    if @gc.state().dragon_picker is @player_id
      pick = util_m.rand_choice [1, 3]
      bot_action @gc, 'pick', [pick], 300
  action: ->
  cleanup: ->


exports.AI = (gc, player_id) ->
  GrandTichu: (new GrandTichuHandler gc, player_id)
  Pass: (new PassHandler gc, player_id)
  Play: (new PlayHandler gc, player_id)
  PickDragon: (new PickDragonHandler gc, player_id)
