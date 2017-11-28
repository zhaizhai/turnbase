assert = require 'assert'
tichu_logic_m = require '../tichu_logic.iced'
test_util_m = require './test_util'

HA = test_util_m.HandArrays
HandGenerator = test_util_m.HandGenerator
InteractiveTester = test_util_m.InteractiveTester
make_card = test_util_m.make_card
make_hand = test_util_m.make_hand


bomb8 = HA.bomb 8

# ph: previous hand, ch: current hand
# expected: true if ch can play over ph
PLAYABLE_OVER_TEST_CASES = [
  {ph: bomb8, ch: HA.tuple(11, 1), expected:false}
  {ph: bomb8, ch: HA.tuple(11, 2), expected:false}
  {ph: bomb8, ch: HA.tuple(11, 3), expected:false}
  {ph: HA.straight_flush(8,5), ch: bomb8, expected:false}
  # test that things are playable over nothing
  {ph: [], ch: HA.single(9), expected:true}
  {ph: [], ch: HA.pair(14), expected:true}
  {ph: [], ch: HA.triple(2), expected:true}
  {ph: [], ch: HA.tractor(3, 5), expected:true}
  {ph: [], ch: HA.tractor(6, 2), expected:true}
  {ph: [], ch: HA.fh(2, 3), expected:true}
  {ph: [], ch: HA.straight(2, 6), expected:true}
  {ph: [], ch: HA.straight(2, 4), expected:false}
]

print_info = (test_case) ->
  {ph, ch, expected} = test_case
  console.log "previous hand: #{ph}"
  console.log "current hand: #{ch}"
  console.log "expected: #{expected}"

test_is_playable_over = ->
  for test_case, i in PLAYABLE_OVER_TEST_CASES
    {ph, ch, expected} = test_case
    prev_hand = make_hand ph
    cur_hand = make_hand ch
    try
      actual = tichu_logic_m.is_playable_over cur_hand, prev_hand
    catch e
      console.log "Test case #{i} FAILED!"
      console.log e
      print_info test_case
      # throw e
      continue
    if expected == actual
      console.log "Test case #{i} passed."
    else
      console.log "Test case #{i} FAILED!"
      print_info test_case



tester = new InteractiveTester ->
  prev_hand = HandGenerator.draw_random_play()
  cur_hand = HandGenerator.draw_random_play()

  console.log '>>cur hand', test_util_m.hand_to_str_arr cur_hand
  console.log '>>prev hand', test_util_m.hand_to_str_arr prev_hand

  expected = tichu_logic_m.is_playable_over cur_hand, prev_hand
  console.log 'program thinks you can play?', expected

  return {
    ph: test_util_m.hand_to_str_arr prev_hand
    ch: test_util_m.hand_to_str_arr cur_hand
    expected: expected
  }

test_is_playable_over()
# tester.run()
