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

Player = Turnbase.struct 'Player', {
  cards: T.ArrayOf MCard
  tricks_taken: T.Integer
  bid: T.Nullable T.Integer

  is_void_in: (suit) ->
    return util_m.all (c.suit isnt suit for c in @cards)
}

winner_idx_of_trick = (played_cards) ->
  winner = { card: played_cards[0], idx: 0 }
  for card, idx in played_cards
    if card.suit is winner.card.suit
      if card.value > winner.card.value
        winner = { card, idx }
    else if card.suit is 'S'
      winner = { card, idx }
  return winner.idx

Turnbase.state {
  players: T.ArrayOf Player
  num_rounds: T.Integer
}

Turnbase.setup {
  options: [
    Turnbase.option 'Num players: %{num_players}', {
      num_players: Turnbase.select {
        3: 3, 4: 4, 5: 5,
      }, 3
    }
  ]

  init: (initial_data) ->
    num_rounds = Math.floor (52 / initial_data.num_players)
    deck = []
    for value in [2..14]
      for suit in ALL_SUITS
        deck.push (new MCard { suit, value })
    deck = deck.slice (52 - num_rounds * initial_data.num_players)
    util_m.shuffle deck, @RANDOM.rand

    players = []
    for i in [0...initial_data.num_players]
      hand = deck.splice 0, num_rounds
      hand.sort (a, b) ->
        if a.suit is b.suit
          return a.value - b.value
        return (ALL_SUITS.indexOf a.suit) - (ALL_SUITS.indexOf b.suit)
      player = new Player { cards: [], tricks_taken: 0, bid: null }
      for card in hand
        card.add_access i
        player.cards.push card
      players.push player
    return { players: players, num_rounds: num_rounds }
}

Turnbase.mode 'Bid', {
  cur_turn: T.Integer
  players_left_to_bid: T.Integer
  total_bid_so_far: T.Integer

  bid: (num_tricks) ->
    types: [T.Integer]
    validate: ->
      V.assert (@PLAYER is @cur_turn), "Out of turn!"
      V.assert (num_tricks >= 0), "Bid must be non-negative!"
      V.assert (num_tricks + @total_bid_so_far <= @num_rounds), "Total bid can't be higher than number of rounds!"

    execute: ->
      @players[@PLAYER].bid = num_tricks
      @LOG "%{#{@PLAYER}} bids #{num_tricks}!"
      @total_bid_so_far += num_tricks
      @players_left_to_bid -= 1
      @cur_turn = (@cur_turn + 1) % @players.length

      if @players_left_to_bid is 1
        leftover = @num_rounds - @total_bid_so_far
        @players[@cur_turn].bid = leftover
        @LOG "%{#{@cur_turn}} is left with #{leftover} remaining tricks."
        return @LEAVE_MODE()
}

Turnbase.mode 'PlayRound', {
  cur_turn: T.Integer
  cur_trick: T.ArrayOf Card

  play: (card_idx) ->
    types: [T.Integer]
    validate: ->
      V.assert (@PLAYER is @cur_turn), "Out of turn!"
      V.assert (0 <= card_idx and card_idx < @players[@PLAYER].cards.length), "Invalid card index #{card_idx}"
      player = @players[@PLAYER]
      card = player.cards[card_idx]
      if @cur_trick.length > 0
        lead_suit = @cur_trick[0].suit
        if not (player.is_void_in lead_suit)
          V.assert (card.suit is lead_suit), "Must follow suit!"
    execute: ->
      [card] = @players[@PLAYER].cards.splice card_idx, 1
      card = MCard.unmask(card)
      @cur_trick.push card
      @LOG "%{#{@PLAYER}} plays #{card.value}#{card.suit}."
      @cur_turn = (@cur_turn + 1) % @players.length

      if @cur_trick.length is @players.length
        winner_offset = winner_idx_of_trick @cur_trick
        winner = (@cur_turn + winner_offset) % @players.length
        return @LEAVE_MODE winner
}

Turnbase.main ->
  cur_turn = 0
  await @ENTER_MODE 'Bid', {
    cur_turn: cur_turn, players_left_to_bid: @players.length
    total_bid_so_far: 0
  }, defer()

  cur_turn = @players.length - 1
  for i in [0...@num_rounds]
    await @ENTER_MODE 'PlayRound', { cur_turn: cur_turn, cur_trick: [] },
      defer winner
    @LOG "%{#{winner}} takes the trick."
    @players[winner].tricks_taken += 1
    if @players[winner].tricks_taken > @players[winner].bid
      @LOG "You have lost: %{#{winner}} exceeded their bid!"
    cur_turn = winner
  @LOG "All players met their bid. You won!"
  @GAME_OVER()
