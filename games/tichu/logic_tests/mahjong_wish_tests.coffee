assert = require 'assert'
tichu_logic_m = require '../tichu_logic.iced'
test_util_m = require './test_util'

HA = test_util_m.HandArrays
HandGenerator = test_util_m.HandGenerator
InteractiveTester = test_util_m.InteractiveTester
make_card = test_util_m.make_card
make_hand = test_util_m.make_hand


mega_bomb = HA.straight_flush(2,13)
almost_mega_bomb = ['2C'].concat(HA.straight_flush 3, 12, 'S')
hand_no_7 = ['2H', '3H', '4H', '5H', '6H'
             'dog', 'dragon', '5C', '5D', '5S']
hand_bomb_and_fh = ['2H', '2S'].concat(HA.bomb 5)
hand_bomb_and_tractor = ['2H', '2S', '3D', '3C'].concat(HA.bomb 4)


# ph: previous hand, ch: player's current hand
# wish: mahjong wish value
# expected: true if the wish can be satisfied
MAHJONG_WISH_TEST_CASES = [
  # hand without wished card can't satisfy wish
  {ph: [], ch: hand_no_7, wish: 7, expected: false}
  {ph: HA.pair(4), ch: hand_no_7, wish: 7, expected: false}
  # having lead means you satisfy the wish if you have the card
  {ph: [], ch: hand_no_7, wish: 2, expected: true}
  {ph: [], ch: hand_no_7, wish: 5, expected: true}
  {ph: [], ch: hand_no_7, wish: 14, expected: false}
  # no bombing the dog please
  {ph: ['dog'], ch: mega_bomb, wish: 3, expected: false}
  # even if you have a bomb, it needs the wish card to matter
  {ph: HA.straight(2,6), ch: almost_mega_bomb, wish: 2, expected: false}
  {ph: HA.fh(7,3), ch: hand_bomb_and_fh, wish: 2, expected: false}
  {ph: HA.tractor(10,3), ch: hand_bomb_and_tractor, wish: 2, expected: false}
  # it's (usually) hard to play over a bomb
  {ph: HA.bomb(2), ch: ['3H', '3S', '3C', '4H', '4S', '4C', '4D', '5H', '6C', '7C'], wish: 3, expected: false}
  # bombs with the wish (usually) mean the wish is satisfiable
  {ph: HA.pair(3), ch: mega_bomb, wish: 5, expected: true}
  {ph: HA.bomb(14), ch: mega_bomb, wish: 8, expected: true}
  {ph: HA.straight_flush(2, 9), ch: mega_bomb, wish: 10, expected: true}
  {ph: HA.bomb(14), ch: HA.bomb(8), wish: 8, expected: false}
  {ph: HA.straight_flush(3, 5), ch: HA.bomb(8), wish: 8, expected: false}
  {ph: HA.fh(4, 2), ch: mega_bomb, wish: 14, expected: true}
  {ph: HA.tractor(4, 2), ch: mega_bomb, wish: 13, expected: true}
  # no bombs, previous play is tuple
  {ph: HA.single(5), ch: ['5D', '7C', '14D', 'dragon'], wish: 6, expected: false}
  {ph: HA.single(5), ch: ['5D', '7C', '14D', 'dragon', 'p'], wish: 6, expected: false}
  {ph: HA.single(5), ch: ['5D', '7C', '14D', 'dragon', 'p'], wish: 7, expected: true}
  {ph: HA.pair(6), ch: ['5D', '7C', '14D', 'dragon', 'p'], wish: 7, expected: true}
  {ph: HA.pair(6), ch: ['5D', '7C', '7D', '14D', 'dragon', 'p'], wish: 7, expected: true}
  {ph: HA.pair(6), ch: ['5D', '7C', '7D', '14D', 'dragon'], wish: 7, expected: true}
  {ph: HA.pair(8), ch: ['5D', '7C', '7D', '14D', 'dragon'], wish: 7, expected: false}
  {ph: HA.pair(8), ch: ['5D', '7C', '7D', '14D', 'dragon', 'p'], wish: 7, expected: false}
  {ph: HA.pair(6), ch: ['5D', '7C', '7D', '14D', 'dragon', 'p'], wish: 8, expected: false}
  # TODO:
  # cases with each type (tuple1,2,3, fh, straight, tractor)
  # cases with phoenix
]

print_info = (test_case) ->
  {ph, ch, wish, expected} = test_case
  console.log "previous hand: #{ph}"
  console.log "player hand: #{ch}"
  console.log "wish: #{wish}"
  console.log "expected: #{expected}"

test_can_satisfy_mahjong_wish = ->
  for test_case, i in MAHJONG_WISH_TEST_CASES
    {ph, ch, wish, expected} = test_case
    prev_hand = make_hand ph
    player_hand = make_hand ch

    try
      actual = tichu_logic_m.can_satisfy_mahjong_wish prev_hand, player_hand, wish
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
  prev_hand = HandGenerator.draw_random_fullhouse()
  wish = 2 + (test_util_m.rand_int 13)
  player_hand = HandGenerator.draw_n 14, prev_hand

  console.log '>>player hand', test_util_m.hand_to_str_arr player_hand
  console.log '>>prev hand', test_util_m.hand_to_str_arr prev_hand
  console.log '>>wish', wish

  expected = tichu_logic_m.can_satisfy_mahjong_wish prev_hand, player_hand, wish
  console.log 'program thinks you can satisfy wish?', expected

  return {
    prev_hand: test_util_m.hand_to_str_arr prev_hand
    player_hand: test_util_m.hand_to_str_arr player_hand
    wish: wish
    expected: expected
  }

test_can_satisfy_mahjong_wish()
#tester.run()
