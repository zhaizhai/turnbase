assert = require 'assert'
util_m = require 'shared/util.iced'
Turnbase = require 'game_engine/turnbase.iced'
{T,V} = Turnbase

ALL_SUITS = ['C', 'D', 'H', 'S']

Card = Turnbase.struct 'Card', {
  suit: T.String
  value: T.Integer
}
MCard = T.Masked Card

CardKnowledge = Turnbase.struct 'CardKnowledge', {
  known_suit: T.Nullable T.String
  #known_value: T.Nullable T.Integer
  known_min_value: T.Integer
  known_max_value: T.Integer
}

Player = Turnbase.struct 'Player', {
  cards: T.ArrayOf MCard
  knowledge: T.ArrayOf CardKnowledge
}

Turnbase.state {
  players: T.ArrayOf Player
  deck: T.ArrayOf MCard
  dings: T.Integer
  num_jokers: T.Integer
  ladders: T.ArrayOf (T.ArrayOf T.Integer)

  draw_for_player: (player_idx) ->
    player = @players[player_idx]
    drawn = @deck[0]
    @deck = @deck.slice 1

    for i in [0...@players.length]
      if i isnt player_idx
        drawn.add_access i
    player.cards.push drawn
    player.knowledge.push (new CardKnowledge {
      known_suit: null, known_min_value: 2, known_max_value: 14
    })

  # Adds a value to ladder, returning whether the operation was valid.
  add_to_ladder: (ladder_idx, value) ->
    ladder = @ladders[ladder_idx]
    if ladder.length is 0
      ladder.push @card.value
      return true

    if ladder[0] > @card.value
      jokers_needed = ladder[0] - @card.value - 1
      if jokers_needed > @num_jokers
        return false
      @num_jokers -= jokers_needed
      new_ladder = [@card.value].concat (-1 for _ in [0...jokers_needed])
      new_ladder = new_ladder.concat ladder
      @ladders[ladder_idx] = new_ladder
      return true

    if ladder[ladder.length - 1] < @card.value
      jokers_needed = @card.value - ladder[ladder.length - 1] - 1
      if jokers_needed > @num_jokers
        return false
      @num_jokers -= jokers_needed
      for _ in [0...jokers_needed]
        ladder.push -1
      ladder.push @card.value
      return true

    offset = @card.value - ladder[0]
    if ladder[offset] is -1
      @num_jokers += 1
      ladder[offset] = @card.value
      return true

    return false

  game_is_over: ->
    for p in @players
      if p.cards.length > 0
        return false
    return true
}

Turnbase.setup {
  init: (initial_data) ->
    # TODO: add values per suit option
    deck = []
    for suit in ALL_SUITS
      for value in [2..14]
        deck.push (new MCard { suit, value })
    players = for i in [0...initial_data.num_players]
      new Player { cards: [], knowledge: [] }
    return {
      players: players, deck: deck, dings: 0, num_jokers: 2,
      ladders: [[], [], [], []]
    }
}

Turnbase.mode 'PlayTurn', {
  cur_turn: T.Integer

  hint_suit: (player_idx, suit) ->
    types: [T.Integer, T.String]
    validate: ->
      V.assert (@PLAYER is @cur_turn), "Out of turn!"
      V.assert (0 <= player_idx and player_idx < @players.length), "Invalid player id!"
      V.assert (player_idx isnt @PLAYER), "Can't hint yourself!"
      V.assert (suit in ALL_SUITS), "Invalid suit #{suit}!"
    execute: ->
      hinted_player = @players[player_idx]
      matches = []
      for card, idx in hinted_player.cards
        if card.suit is suit
          hinted_player.knowledge[idx].known_suit = suit
          matches.push idx

      @LOG "%{#{@PLAYER}} hints #{suit} for %{#{player_idx}}'s hand."
      @LOG "Matches at indices #{matches}."
      @dings += 1
      return @LEAVE_MODE()

  # Hints everything >= value
  hint_value: (player_idx, value) ->
    types: [T.Integer, T.Integer]
    validate: ->
      V.assert (@PLAYER is @cur_turn), "Out of turn!"
      V.assert (0 <= player_idx and player_idx < @players.length), "Invalid player id!"
      V.assert (player_idx isnt @PLAYER), "Can't hint yourself!"
      V.assert (2 <= value and value <= 14), "Value #{value} out of range!"
    execute: ->
      hinted_player = @players[player_idx]
      matches = []
      for card, idx in hinted_player.cards
        if card.value >= value
          hinted_player.knowledge[idx].known_min_value = value
          matches.push idx
        else
          hinted_player.knowledge[idx].known_max_value = value - 1

      @LOG "%{#{@PLAYER}} hints >= #{value} for %{#{player_idx}}'s hand."
      @LOG "Matches at indices #{matches}."
      @dings += 1
      return @LEAVE_MODE()

  play: (card_idx) ->
    types: [T.Integer]
    validate: ->
      V.assert (@PLAYER is @cur_turn), "Out of turn!"
      V.assert (0 <= card_idx and card_idx < @players[@PLAYER].cards.length), "Card index out of range!"
    execute: ->
      player = @players[@PLAYER]
      player.knowledge.splice card_idx, 1
      [card] = player.cards.splice card_idx, 1
      card = MCard.unmask(card)

      @LOG "%{#{@PLAYER}} plays card #{card_idx}:  #{card.value}#{card.suit}."
      await @ENTER_MODE 'PlayOrDiscard', {
        card: card, cur_turn: @cur_turn
      }, defer()

      if @deck.length > 0
        @draw_for_player @PLAYER
      return @LEAVE_MODE()
}

Turnbase.mode 'PlayOrDiscard', {
  card: Card
  cur_turn: T.Integer

  play: ->
    types: []
    validate: ->
      V.assert (@PLAYER is @cur_turn), "Out of turn!"
    execute: ->
      for suit, idx in ALL_SUITS
        if suit isnt @card.suit
          continue
        was_valid = @add_to_ladder idx, @card.value
        if not was_valid
          @LOG "This card can't be played!"
          return
      return @LEAVE_MODE()

  discard: ->
    types: []
    validate: ->
      V.assert (@PLAYER is @cur_turn), "Out of turn!"
    execute: ->
      @dings += 1
      @LOG "Discarded."
      return @LEAVE_MODE()
}

Turnbase.main ->
  util_m.shuffle @deck, @RANDOM.rand
  for player, player_idx in @players
    for i in [0...5]
      @draw_for_player player_idx
  @LOG "Dealt hands."

  cur_turn = 0
  while not @game_is_over()
    @LOG "%{#{cur_turn}}'s turn."
    await @ENTER_MODE 'PlayTurn', {
      cur_turn: cur_turn
    }, defer()
    cur_turn = (cur_turn + 1) % @players.length

  @GAME_OVER()
