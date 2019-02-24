util_m = require 'shared/util.iced'
{startswith} = util_m
logic = require 'games/tichu/tichu_logic.iced'

test_util_m = require 'games/tichu/logic_tests/test_util'
HA = test_util_m.HandArrays
htsa = test_util_m.hand_to_str_arr

{
  TichuRecurser, extract
} = require 'bots/tichu/plan_recurse.iced'


class TopK
  constructor: (@k) ->
    @_top = []

  best_value: -> @_top[0].value

  top: -> @_top

  add: (item, value) ->
    idx = 0
    while idx < @_top.length and @_top[idx].value > value
      idx += 1
    @_top.splice idx, 0, {item, value}
    if @_top.length > @k
      @_top = @_top.slice 0, @k


class PlanEvaluator
  constructor: ->
    @_recurser = new TichuRecurser

  consider_all_plans: (hand, take_top = 5) ->
    best = new TopK take_top

    @_recurser.chain_extract hand, [
      extract.straights, (extract.tuples 3),
      extract.fullhouses, extract.tractors,
      (extract.tuples 2)
    ], (plays_so_far, hand_left) =>
      single_plays = ([x] for x in hand_left)
      plan = plays_so_far.concat single_plays
      best.add plan, (@evaluate_plan plan)
    # note that chain_extract is completely synchronous
    return best.top()[0]

  evaluate_plan: (plays) ->
    ret = 0
    for play in plays
      ret += @evaluate_play play
      if isNaN ret
        console.log 'Got invalid play', play
        throw new Error "bad play"
    return ret

  evaluate_play: (play) ->
    result = logic.evaluate_hand play
    if not result?
      console.log "Invalid play", play
      throw new Error "Invalid play!"

    {type, value} = result
    if startswith type, 'TUPLE'
      if play.length is 1
        return @_evaluate_single value
      else if play.length is 2
        return @_evaluate_pair value
      else if play.length is 3
        return @_evaluate_triple value
      throw new Error "play length #{play.length} not handled"

    else if startswith type, 'STRAIGHT'
      return @_evaluate_straight value, play.length

    else if type is 'FULLHOUSE'
      return @_evaluate_fullhouse value

    else if startswith type, 'TRACTOR'
      return @_evaluate_tractor value, (play.length / 2)

    else if type is 'DOG'
      return -1

    else if type is 'BOMB'
      return 1

    throw new Error "Unhandled type #{type}"

  STRAIGHT_VALS = [
    null, -0.25, -0.20, -0.15, -0.05,
    -0.05, 0.00, 0.05,  0.10,  0.15,
    0.20
  ]
  _evaluate_straight: (value, len) ->
    r = 1 + ((len - 5) / 3)
    return STRAIGHT_VALS[value] / r

  TRACTOR_VALS = [
    null,  null,  -0.20, -0.20, -0.15,
    -0.15, -0.10, -0.05,  0.00,  0.05,
    0.10,  0.15,  0.20,  0.30
  ]
  _evaluate_tractor: (value, len) ->
    r = len - 1
    return TRACTOR_VALS[value] / r

  # TODO: probably lower these values
  FH_VALS = [
    null, null, -0.10, -0.10, -0.05,
    0.00, 0.00, 0.05,  0.05,  0.05,
    0.05, 0.10, 0.10,  0.15,  0.20
  ]
  _evaluate_fullhouse: (value) ->
    return FH_VALS[value]

  SINGLE_VALS = [
    null,  -1.00, -0.95, -0.95, -0.95,
    -0.80, -0.60, -0.40, -0.20, -0.10,
    -0.05,  0.00,  0.10,  0.20,  0.95,
    null,   null,  1.00 # dragon is 17
  ]
  _evaluate_single: (value) ->
    return SINGLE_VALS[value]

  PAIR_VALS = [
    null,  null,  -0.90, -0.85, -0.80,
    -0.65, -0.50, -0.35, -0.15, -0.05,
    0.05,  0.10,  0.20,  0.40,  0.95
  ]
  _evaluate_pair: (value) ->
    return PAIR_VALS[value]

  TRIPLE_VALS = [
    null,  null, -0.30, -0.20, -0.15,
    -0.05, 0.00, 0.05,  0.10,  0.10,
    0.15,  0.15, 0.15,  0.20,  0.25
  ]
  _evaluate_triple: (value) ->
    return TRIPLE_VALS[value]

exports.PlanEvaluator = PlanEvaluator