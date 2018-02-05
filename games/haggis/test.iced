log = (require 'shared/log.iced') 'test.iced'
#{GameTester, define_states} = require 'game_engine/testing/game_tester.iced'
#{GameSpec} = require 'game_engine/game_spec.iced'
#{ConsolePrinter} = require 'game_engine/testing/state_printer.iced'

logic_m = require 'games/haggis/haggis_logic.iced'

parse_hand = (hand) ->
  ret = []
  for s in hand
    ret.push { suit: s[0], value: parseInt s[1...] }
  return ret

SINGLE4 = parse_hand ['C4']
PAIR3 = parse_hand ['A3', 'B3']
PAIR4 = parse_hand ['A4', 'B4']
PAIR10 = parse_hand ['A10', 'B10']
#JQK_SEQUENCE = parse_hand ['J11', 'Q12', 'K13']
ODDS = parse_hand ['B3', 'C5', 'A7', 'D9']
ODDS_INVALID = parse_hand ['B3', 'C5', 'C7', 'D9']
ODDS_SUITED = parse_hand ['B3', 'B5', 'B7', 'B9']
JQ_BOMB = parse_hand ['J0', 'Q0']
JQK_BOMB = parse_hand ['J0', 'Q0', 'K0']
SINGLE_K = parse_hand ['K0']

describe 'haggis hand logic', ->
  describe 'evaluate_hand', ->
    check_eval = (hand, type, value) ->
      if type?
        expect(logic_m.evaluate_hand hand).toEqual {type, value}
      else
        expect(logic_m.evaluate_hand hand).toBe null

    it 'evaluates singles and tuples correctly', ->
      check_eval SINGLE4, 'SEQ1:1', 4
      check_eval PAIR3, 'SEQ2:1', 3

    it 'evaluates odds bombs correctly', ->
      check_eval ODDS, 'BOMB', 0
      check_eval ODDS_SUITED, 'BOMB', 5
      check_eval ODDS_INVALID, null

    it 'evaluates face bombs correctly', ->
      check_eval JQ_BOMB, 'BOMB', 1
      check_eval JQK_BOMB, 'BOMB', 4

  describe 'is_playable_over', ->
    it 'allows playing over with same type and higher value', ->
      expect(logic_m.is_playable_over PAIR4, PAIR3).toBe true

    it 'allows bombs to be played over sequences', ->
      expect(logic_m.is_playable_over JQ_BOMB, PAIR10).toBe true

    it 'handles the case when the hand is being led', ->
      expect(logic_m.is_playable_over (parse_hand ['A3', 'B5']), null).toBe false
      expect(logic_m.is_playable_over SINGLE4, null).toBe true

  describe 'valid_wild_values', ->
    it 'only allows all-wild hands to be played as bombs', ->
      vals = logic_m.valid_wild_values JQ_BOMB, PAIR10
      expect(vals.length).toBe 1
      vals = logic_m.valid_wild_values JQK_BOMB, PAIR10
      expect(vals.length).toBe 1
