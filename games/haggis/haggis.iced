assert = require 'assert'
util_m = require 'shared/util.iced'
Turnbase = require 'game_engine/turnbase.iced'
{T,V} = Turnbase
logic_m = require 'games/haggis/haggis_logic.iced'

Card = Turnbase.struct 'Card', {
  suit: T.String
  value: T.Integer
}
MCard = T.Masked Card

Player = Turnbase.struct 'Player', {
  cards: T.ArrayOf MCard
  total_points: T.Integer
  round_points: T.Integer

  is_out: ->
    return @cards.length == 0
  num_cards: ->
    return @cards.length
}

Trick = Turnbase.struct 'Trick', {
  plays: T.ArrayOf (T.ArrayOf Card)
  total_points: ->
    ret = 0
    for play in @plays
      ret += logic_m.points_value play
    return ret
  last_play: ->
    return util_m.last @plays
}

Turnbase.state {
  players: (T.ArrayOf Player)

  redeal: (rand = null) ->
    deck = logic_m.make_deck()
    deck = ((new MCard card) for card in deck)
    util_m.shuffle deck, rand

    for player, i in @players
      hand = deck.slice(i * 14, (i + 1) * 14)
      wilds = (new MCard c for c in logic_m.make_wilds())
      hand = hand.concat wilds
      for card in hand
        card.add_access i
      hand = logic_m.sorted_by_value hand
      player.cards = hand
}

Turnbase.setup {
  init: (initial_data) ->
    players = for i in [0, 1]
      new Player { cards: [], total_points: 0, round_points: 0 }
    return {players: players}
}

Turnbase.mode 'PlayTrick', {
  cur_turn: T.Integer
  cur_trick: Trick

  _extract_play: (hand, card_indices, wild_values) ->
    ret = []
    for card_idx, i in card_indices
      card = MCard.unmask hand[card_idx]
      wild_val = wild_values[i]
      if wild_val?
        if not (logic_m.is_wild card) then return null
        # TODO: check that the wild value is valid
        card.value = wild_val
      ret.push card
    return (logic_m.sorted_by_value ret)

  play: (card_indices, wild_values) ->
    types: [(T.ArrayOf T.Integer), (T.ArrayOf (T.Nullable T.Integer))]
    validate: ->
      V.assert (@PLAYER is @cur_turn), "It's not your turn!"
      hand = @players[@PLAYER].cards
      play = @_extract_play hand, card_indices, wild_values
      V.assert play?, "Wild values are not valid!"
      console.log 'Extracted play', play
      last = @cur_trick.last_play()
      V.assert (logic_m.is_playable_over play, last), "Can't play that over the last play!"
    execute: ->
      hand = @players[@PLAYER].cards
      play = @_extract_play hand, card_indices, wild_values
      @LOG "%{#{@PLAYER}} plays #{logic_m.display_string(play)}."
      @players[@PLAYER].cards = (c for c, idx in hand when idx not in card_indices)
      @cur_trick.plays.push play
      @cur_turn = (@cur_turn + 1) % @players.length

      if @players[@PLAYER].cards.length is 0
        return @LEAVE_MODE @PLAYER

  pass: ->
    types: []
    validate: ->
      V.assert (@PLAYER is @cur_turn), "It's not your turn!"
      V.assert @cur_trick.last_play()?, "You can't pass when it's your lead!"
    execute: ->
      @LOG "%{#{@PLAYER}} passes. %{#{1 - @PLAYER}} takes the trick!"
      winning_info = logic_m.evaluate_hand @cur_trick.last_play()
      if winning_info.type is 'BOMB'
        @players[@PLAYER].round_points += @cur_trick.total_points()
      else
        @players[1 - @PLAYER].round_points += @cur_trick.total_points()
      @LEAVE_MODE (1 - @PLAYER) # TODO: handle 3 players
}

Turnbase.main ->
  winner = null
  while not winner?
    @redeal @RANDOM.rand
    lead = 0

    while util_m.all (p.cards.length > 0 for p in @players)
      await @ENTER_MODE 'PlayTrick', {
        cur_turn: lead, cur_trick: {plays: []}
      }, defer winner
      lead = winner

    @players[lead].round_points += 5 * @players[1 - lead].cards.length
    @LOG "%{#{lead}} wins the round! (#{@players[lead].round_points} to #{@players[1 - lead].round_points})"

    for player, idx in @players
      player.total_points += player.round_points
      player.round_points = 0
      if player.total_points >= 350
        winner = idx

  @LOG "%{#{winner}} has won! (#{@players[winner].total_points} to #{@players[1 - winner].total_points})"
  @GAME_OVER()