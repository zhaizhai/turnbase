assert = require 'assert'
EventEmitter = (require 'events').EventEmitter

util_m = require 'shared/util.iced'
{T, struct} = require 'shared/T/T.iced'
{V} = require 'shared/T/validation.iced'

{make_game} = require 'game_spec/game_config.iced'

logic = require 'games/shengji/shengji_logic.iced'


Card = struct 'Card', {
  suit: T.String
  value: T.Number
}
MCard = T.Masked Card

Player = struct 'Player', {
  cards: T.ArrayOf MCard
  points: T.Integer
  level: T.Integer

  validate_cards: (cards) ->
    for idx, pos in cards
      if (pos < @cards.length - 1 and
          idx >= @cards[pos + 1])
        return V.r false, "Indices must be strictly increasing"
      if idx < 0 or idx >= @cards.length
        return V.r false, "Index out of range"
    return V.r true
}

Trick = struct 'Trick', {
  cards: T.ArrayOf (T.ArrayOf Card)
  lead: T.Integer
}

ShengJiGameState = struct 'ShengJiGameState', {
  players: T.ArrayOf Player
  master: (T.Nullable T.Integer)
  trump_value: T.Integer
  trump_suit: (T.Nullable T.String)

  is_game_over: ->
    for player in @players
      if player.level > 14
        return true
    return false

  score_round: (opp_pts) ->
    if opp_pts < 40
      jump = 2 - (Math.floor (opp_pts / 20))
      for player, idx in @players
        if (idx % 2) == (@master % 2)
          player.level += jump
      @master = (@master + 2) % 4
      return

    jump = (Math.floor (opp_pts / 20)) - 2
    for player, idx in @players
      if (idx % 2) != (@master % 2)
        player.level += jump
    @master = (@master + 1) % 4

  ctx: ->
    return {trump_value: @trump_value, trump_suit: @trump_suit}

  remove_cards: (player_id, card_idxs) ->
    player = @players[player_id]

    to_remove = []
    new_hand = []
    for card, idx in player.cards
      if idx in card_idxs
        to_remove.push card
      else
        new_hand.push card
    player.cards = new_hand
    return to_remove
}

ShengJi = make_game {
  STATE: ShengJiGameState
  JS_DEPS: ['&jquery', 'shengji/shengji_client.iced']
  CSS_DEPS: ['../games/shengji/shengji.css']
  DEFAULTS:
    num_players: 4

  SETUP: (initial_data) ->
    {num_players} = initial_data
    if num_players isnt 4
      throw new Error "Must play with 4 players"

    players = []
    for i in [0...4]
      players.push new Player {
        cards: []
        points: 0
        level: 2
      }

    return new ShengJiGameState {
      players: players
      master: null
      trump_value: 2
      trump_suit: null
    }

  Main: ->
    while not @STATE.is_game_over() # TODO: report winner
      deck = []
      for suit in 'CDHS'
        for value in [2..14]
          deck.push new MCard {suit, value}
      deck.push new MCard {suit: 'joker', value: 0}
      deck.push new MCard {suit: 'joker', value: 1}
      @RANDOM.shuffle deck

      for player in @STATE.players
        player.points = 0
      await @PUSH_MODE 'Draw', {
        deck: deck
        declared: null
        cur_player: 0
      }, defer()

      await @PUSH_MODE 'Bury', {
        num_to_bury: 6
      }, defer to_bury

      await @PUSH_MODE 'Play', {
        buried: to_bury
        cur_turn: @STATE.master
        cur_trick: null
      }, defer buried, opp_pts
      points_team = (@STATE.master + 1) % 2
      @STATE.score_round opp_pts

      # TODO: pass along pt values too, probably..
      await @PUSH_MODE 'Review', {
        buried: buried
        points_team: points_team
        points_taken: opp_pts
        ready: [false, false, false, false]
      }, defer()
    @GAME_OVER()

  Draw:
    deck: T.ArrayOf MCard
    declared: (T.Nullable T.String) # TODO: eliminate the redundancy with @STATE.trump_suit
    cur_player: T.Integer

    declare: (idx) ->
      types: [T.Integer]
      validate: ->
        return V.check [
          [(not @declared?), "Someone already declared!"]
          => (@STATE.players[@PLAYER].validate_cards [idx])
          =>
            card = @STATE.players[@PLAYER].cards[idx]
            if card.value isnt @STATE.trump_value
              return V.r false, "Wrong value"
            return V.r true
        ]
      execute: ->
        player = @STATE.players[@PLAYER]
        @declared = player.cards[idx].suit
        @STATE.trump_suit = @declared

        # this should only happen at level 2
        if not @STATE.master?
          @STATE.master = @PLAYER

        if @deck.length > 6
          # TODO: maybe just auto-deal at this point
          return
        assert @deck.length is 6
        for c in @deck
          c.add_access @STATE.master
          @STATE.players[@STATE.master].cards.push c
        return @POP_MODE()

    # TODO: have server do this
    draw: ->
      types: []
      validate: ->
        return V.check [
          [(@PLAYER is @cur_player), "Out of turn!"]
          [(@deck.length > 6), "Remaining cards are to be buried!"]
        ]
      execute: ->
        [drawn] = @deck.splice 0, 1
        drawn.add_access @PLAYER
        @STATE.players[@PLAYER].cards.push drawn
        @cur_player = (@cur_player + 1) % @STATE.players.length

        if @deck.length > 6
          return
        if not @declared?
          return

        assert @deck.length is 6
        for c in @deck
          c.add_access @STATE.master
          @STATE.players[@STATE.master].cards.push c
        return @POP_MODE()

  Bury:
    num_to_bury: T.Integer
    bury: (cards) ->
      types: [(T.ArrayOf T.Integer)]
      validate: ->
        return V.check [
          [(@STATE.master is @PLAYER), "Player #{@PLAYER} cannot bury!"]
          => (@STATE.players[@PLAYER].validate_cards cards)
          [(cards.length is @num_to_bury), "Wrong number of cards"]
        ]
      execute: ->
        to_bury = @STATE.remove_cards @STATE.master, cards
        for player in @STATE.players
          player.cards.sort (logic.by_suit @STATE.ctx())
        return @POP_MODE to_bury

  Play:
    buried: T.ArrayOf MCard
    cur_turn: T.Integer
    # TODO: maybe track history of tricks?
    cur_trick: T.Nullable Trick

    play: (cards) ->
      types: [(T.ArrayOf T.Integer)]
      validate: ->
        return V.check [
          [(@cur_turn is @PLAYER), "Out of turn!"]
          => (@STATE.players[@PLAYER].validate_cards cards)
          =>
            player = @STATE.players[@PLAYER]
            if @cur_trick?
              return logic.validate_play @cur_trick.cards[0], cards,
                player.cards, @STATE.ctx()
            return logic.validate_lead cards, @STATE.ctx()
        ]
      execute: ->
        to_play = @STATE.remove_cards @PLAYER, cards
        to_play = (MCard.unmask c for c in to_play)

        if not @cur_trick?
          @cur_trick = new Trick {
            cards: [to_play]
            lead: @PLAYER
          }
          @cur_turn = (@PLAYER + 1) % @STATE.players.length
        else
          @cur_trick.cards.push to_play
          @cur_turn = (@cur_turn + 1) % @STATE.players.length

        if @cur_trick.cards.length isnt @STATE.players.length
          # trick is not over
          return

        # trick is over
        winner = logic.winner_idx @cur_trick.cards, @STATE.ctx()
        for play in @cur_trick.cards
          pts = logic.gather_points play
          @STATE.players[winner].points += pts
        @cur_turn = (@cur_trick.lead + winner) % 4
        @DELIMIT 'pause'

        @cur_trick = null
        if @STATE.players[0].cards.length > 0
          return # round not over

        # round over
        buried = (MCard.unmask c for c in @buried)
        buried_pts = 2 * (logic.gather_points buried)

        opp_pts = 0
        if (winner % 2) != (@STATE.master % 2)
          opp_pts += buried_pts
        for player, idx in @STATE.players
          if (idx % 2) != (@STATE.master % 2)
            opp_pts += player.points
        return @POP_MODE buried, opp_pts


  Review:
    buried: (T.ArrayOf Card)
    points_team: T.Integer
    points_taken: T.Integer
    ready: (T.ArrayOf T.Boolean)

    continue: ->
      types: []
      validate: -> V.check [
          [not @ready[@PLAYER], "Already continued"]
        ]
      execute: ->
        @ready[@PLAYER] = true
        if util_m.all @ready
          return @POP_MODE()
}

exports.DISPLAY_NAME = '40 points'
exports.CONFIG_ARGS = ShengJi
exports.ShengJiGameState = ShengJiGameState
