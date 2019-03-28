util_m = require 'shared/util.iced'

test_util_m = require 'testing/test_util.iced'
{CardGenerator, HandGenerator, InteractiveTester} = test_util_m

logic = require 'games/shengji/shengji_logic.iced'

rand_ctx = ->
  return {
    trump_value: util_m.rand_choice [2..14]
    trump_suit: util_m.rand_choice 'CDHS'
  }

cg = new CardGenerator {
  small: {suit: 'joker', value: 0}
  big: {suit: 'joker', value: 1}
}
hg = new HandGenerator cg

TEST_CASES = [
  {
    ctx:
      trump_value: 2
      trump_suit: 'D'
    trick: [['4S'], ['KD'], ['AD'], ['8S']]
    winner: 2
  }
]
expect_equal = (a, b) ->
  if a isnt b
    throw new Error "Expected #{a} to be #{b}!"

for {ctx, trick, winner} in TEST_CASES
  for i in [0...4]
    trick[i] = (cg.from_str c for c in trick[i])
  expect_equal (logic.winner_idx trick, ctx), winner

tester = new InteractiveTester ->
  ctx = rand_ctx()
  console.log '>> ctx:', ctx

  lead = hg.draw_n 1
  eff_suit = logic.get_suit lead[0], ctx

  trick = [lead]
  for i in [0...3]
    filter = (c) ->
      eff_suit is (logic.get_suit c, ctx)
    play = hg.draw_n 1#, filter
    trick.push play

  winner = logic.winner_idx trick, ctx
  console.log '>> trick:', (cg.to_str p[0] for p in trick)
  console.log '>> winner:', winner
  return {
    trick: trick
    winner: winner
  }

tester.run()