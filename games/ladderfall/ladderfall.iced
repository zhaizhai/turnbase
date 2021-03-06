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
  #known_suit: T.string
  possible_suits: T.ArrayOf T.String
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
  cards_per_suit: T.Integer
  num_jokers: T.Integer
  plays_this_turn: T.Integer
  suits: T.ArrayOf T.String
  ladders: T.ArrayOf (T.ArrayOf T.Integer)
  discards: T.ArrayOf (T.ArrayOf T.Integer)

  draw_for_player: (player_idx) ->
    player = @players[player_idx]
    drawn = @deck[0]
    @deck = @deck.slice 1

    for i in [0...@players.length]
      if i isnt player_idx
        drawn.add_access i
    player.cards.push drawn
    player.knowledge.push (new CardKnowledge {
      possible_suits: ALL_SUITS.slice(),
      known_min_value: 2,
      known_max_value: 1 + @cards_per_suit
    })

  # Adds a value to ladder, returning whether the operation was valid.
  add_to_ladder: (suit_idx, value) ->
    ladder = @ladders[suit_idx]
    discard = @discards[suit_idx]

    prepend_discard_to_ladder = () =>
      found = true
      looking_for = @card.value - 1
      while found
        idx = discard.indexOf looking_for
        if idx is -1
          break
        discard.splice idx, 1
        ladder = [looking_for].concat ladder
        looking_for -= 1

    append_discard_to_ladder = () =>
      found = true
      looking_for = @card.value + 1
      while found
        idx = discard.indexOf looking_for
        if idx is -1
          break
        discard.splice idx, 1
        ladder.push looking_for
        looking_for += 1

    if ladder.length is 0
      ladder.push @card.value
      prepend_discard_to_ladder()
      append_discard_to_ladder()
      @ladders[suit_idx] = ladder
      @discards[suit_idx] = discard
      return true

    if ladder[0] > @card.value
      jokers_needed = ladder[0] - @card.value - 1
      for value in discard
        if value > @card.value and ladder[0] > value
          jokers_needed -= 1
      if jokers_needed > @num_jokers
        return false
      @num_jokers -= jokers_needed
      val_to_add = ladder[0] - 1
      while val_to_add > @card.value
        idx = discard.indexOf val_to_add
        if idx is -1
          ladder = [-1].concat ladder
        else
          discard.splice idx, 1
          ladder = [val_to_add].concat ladder
        val_to_add -= 1
      ladder = [@card.value].concat ladder
      prepend_discard_to_ladder()
      @ladders[suit_idx] = ladder
      @discards[suit_idx] = discard
      return true

    if ladder[ladder.length - 1] < @card.value
      jokers_needed = @card.value - ladder[ladder.length - 1] - 1
      for value in discard
        if value < @card.value and ladder[0] < value
          jokers_needed -= 1
      if jokers_needed > @num_jokers
        return false
      @num_jokers -= jokers_needed
      val_to_add = ladder[ladder.length - 1] + 1
      while val_to_add < @card.value
        idx = discard.indexOf val_to_add
        if idx is -1
          ladder.push -1
        else
          discard.splice idx, 1
          ladder.push val_to_add
        val_to_add += 1
      ladder.push @card.value
      append_discard_to_ladder()
      @ladders[suit_idx] = ladder
      @discards[suit_idx] = discard
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
  options: [
    Turnbase.option 'Num players: %{num_players}', {
      num_players: Turnbase.select {
        2: 2, 3: 3, 4: 4
      }, 2
    }
    Turnbase.option 'Play with %{cards_per_suit} cards per suit and %{num_jokers} jokers', {
      cards_per_suit: Turnbase.select {
        9: 9, 10: 10, 11: 11, 12: 12, 13: 13
      }, 13
      num_jokers: Turnbase.select {
        2: 2, 3: 3, 4: 4
      }, 2
    }
  ]

  init: (initial_data) ->
    deck = []
    for suit in ALL_SUITS
      for value in [2..(1 + initial_data.cards_per_suit)]
        deck.push (new MCard { suit, value })
    players = for i in [0...initial_data.num_players]
      new Player { cards: [], knowledge: [] }
    return {
      cards_per_suit: initial_data.cards_per_suit
      num_jokers: initial_data.num_jokers
      players: players, deck: deck, dings: 0
      ladders: ([] for suit in ALL_SUITS)
      discards: ([] for suit in ALL_SUITS)
      suits: ALL_SUITS
      plays_this_turn: 0
    }
}

Turnbase.mode 'PlayOrPass', {
  cur_turn: T.Integer

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

      @plays_this_turn += 1

  pass: () ->
    types: []
    validate: ->
      V.assert (@PLAYER is @cur_turn), "Out of turn!"
    execute: ->
      @LOG "%{#{@PLAYER}} declines to play (#{@plays_this_turn} total)."

      for i in [0...@plays_this_turn]
        if @deck.length > 0
          @draw_for_player @PLAYER

      return @LEAVE_MODE()
}

Turnbase.mode 'HintOrPass', {
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
          hinted_player.knowledge[idx].possible_suits = [suit]
          matches.push idx
        else
          hinted_player.knowledge[idx].possible_suits = (possible_suit for possible_suit in hinted_player.knowledge[idx].possible_suits when possible_suit isnt suit)

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
          hinted_player.knowledge[idx].known_min_value = (
            Math.max value, hinted_player.knowledge[idx].known_min_value)
          matches.push idx
        else
          hinted_player.knowledge[idx].known_max_value = (
            Math.min (value - 1), hinted_player.knowledge[idx].known_max_value)

      @LOG "%{#{@PLAYER}} hints >= #{value} for %{#{player_idx}}'s hand."
      @LOG "Matches at indices #{matches}."
      @dings += 1
      return @LEAVE_MODE()

  pass: () ->
    types: []
    validate: ->
      V.assert (@PLAYER is @cur_turn), "Out of turn!"
      V.assert (@plays_this_turn > 0), "Must give hint if made no plays!"

    execute: ->
      @LOG "%{#{@PLAYER}} declines to give a hint."

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
      # TODO: disallow discard if it uses no jokers
    execute: ->
      @dings += 2

      for suit, idx in ALL_SUITS
        if suit is @card.suit
          @discards[idx].push @card.value
          break

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
    @plays_this_turn = 0
    @LOG "%{#{cur_turn}}'s turn."
    await @ENTER_MODE 'PlayOrPass', {
      cur_turn: cur_turn
    }, defer()
    await @ENTER_MODE 'HintOrPass', {
       cur_turn: cur_turn
    }, defer()
    cur_turn = (cur_turn + 1) % @players.length

  @GAME_OVER()
