log = (require 'shared/log.iced') 'test.iced'
{GameTester, define_states} = require 'game_engine/testing/game_tester.iced'
{GameSpec} = require 'game_engine/game_spec.iced'

#{ConsolePrinter} = require 'game_engine/testing/state_printer.iced'

Battleship = new GameSpec 'battleship'

STATES = define_states {
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
  BeginGuessing: [
    "AlmostDonePlacing"
    [1, 'place', [3, 3, 3, false]]
    [0, 'done', []]
    [1, 'done', []]
  ]
  AlmostWon: [
    "BeginGuessing"
  ].concat((->
    ret = []
    for i in [0...4]
      for j in [0...(i+2)]
        ret.push [0, 'guess', [i, i+j]]
        ret.push [1, 'guess', [i, i+j]]
    return ret.slice(0, ret.length - 2)
  )())
}

describe 'battleship game logic', ->
  log.set_flag 'info', false

  it 'handles Place.place correctly', (done) ->
    tester = new GameTester Battleship
    await tester.test_actions STATES.PlacedAFewShips, defer()

    placements = tester.server_state().players[0].placements
    expect(placements.get(0, 1)).toEqual(0)
    expect(placements.get(1, 3)).toEqual(1)
    expect(placements.get(2, 4)).toEqual(2)
    expect(tester.is_valid 0, 'place', [3, 0, 3, false]).toBe(false)
    done()

  it 'handles Place.done correctly', (done) ->
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
    done()

  it 'handles Guess.guess correctly', (done) ->
    tester = new GameTester Battleship
    await tester.test_actions STATES.BeginGuessing, defer()
    expect(tester.mode_name()).toBe('Guess')

    expect(tester.is_valid 1, 'guess', [0, 0]).toBe(false)
    expect(tester.is_valid 0, 'guess', [-1, -1]).toBe(false)

    await tester.test_actions [
      [0, 'guess', [0, 0]]
      [1, 'guess', [1, 1]]
      [0, 'guess', [2, 0]]
    ], defer()

    state = tester.server_state()
    guesses0 = state.players[0].guesses
    guesses1 = state.players[1].guesses
    expect(guesses0.get(0, 0)).toBe("hit")
    expect(guesses0.get(2, 0)).toBe("miss")
    expect(tester.is_valid 1, 'guess', [1, 1]).toBe(false)
    #tester.print_state()
    done()

  it 'can detect when the game is won', (done) ->
    tester = new GameTester Battleship
    await tester.test_actions STATES.AlmostWon, defer()
    await tester.test_actions [
      [0, 'guess', [5, 0]]
      [1, 'guess', [3, 7]] # should be game-ending
    ], defer()

    # TODO: temporary hack for checking that game is over; we haven't
    # fully implemented game over behavior yet
    expect(tester.mode_name()).toBe('Main')
    done()