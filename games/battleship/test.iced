log = (require 'shared/log.iced') 'states.iced'
{GameTester} = require 'game_engine/testing/game_tester.iced'
{GameSpec} = require 'game_engine/game_spec.iced'

Battleship = new GameSpec 'battleship'

# TODO: make pretty console printer for game states...

STATES =
  PlacedAFewShips: [
    [0, 'start', []]
    [0, 'place', [0, 0, 0, true]]
    [0, 'place', [1, 1, 1, true]]
    [0, 'place', [2, 2, 2, true]]
  ]
  AlmostDonePlacing: [
    "PlacedAFewShips"
    [0, 'place', [3, 3, 3, true]]
    [1, 'place', [0, 0, 0, false]]
    [1, 'place', [1, 1, 1, false]]
    [1, 'place', [2, 2, 2, false]]
  ]

expand_state = (state_name) ->
  actions = STATES[state_name].slice()
  initial = actions[0]
  if typeof initial is 'string'
    actions.splice 0, 1, expand_state(initial)...
  return actions

for k, v of STATES
  STATES[k] = expand_state(k)

describe 'battleship game logic', ->
  log.set_flag 'info', false

  it 'handles Place.place action correctly', (done) ->
    tester = new GameTester Battleship
    await tester.test_actions STATES.PlacedAFewShips, defer()

    placements = tester.server_state().players[0].placements
    expect(placements.get(0, 1)).toEqual(0)
    expect(placements.get(1, 3)).toEqual(1)
    expect(placements.get(2, 4)).toEqual(2)
    expect(tester.is_valid 0, 'place', [3, 0, 3, false]).toBe(false)
    done()

  it 'handles Place.done action correctly', ->
    tester = new GameTester Battleship
    await tester.test_actions STATES.AlmostDonePlacing, defer()

    expect(tester.is_valid 0, 'done', []).toBe(true)
    expect(tester.is_valid 1, 'done', []).toBe(false)
    await tester.test_actions [
      [0, 'done', []]
      [1, 'place', [3, 3, 3, false]]
      [1, 'done', []]
    ], defer()
    expect(tester.mode_name()).toBe('Guess')