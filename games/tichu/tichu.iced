assert = require 'assert'
util_m = require 'shared/util.iced'
{T, struct} = require 'shared/T/T.iced'
{V} = require 'shared/T/validation.iced'
Turnbase = require 'game_engine/turnbase.iced'

logic = require 'games/tichu/tichu_logic.iced'
tichu_helpers_m = require 'games/tichu/tichu_helpers.iced'

Card = struct 'Card', {
  suit: T.String
  value: T.Number
}
MCard = T.Masked Card

Player = struct 'Player', {
  cards: T.ArrayOf MCard
  tichu_level: T.Integer
  points_taken: (T.ArrayOf Card)

  is_out: ->
    return @cards.length == 0

  num_cards: ->
    return @cards.length
}

Trick = struct 'Trick', {
  cards: T.ArrayOf (T.ArrayOf Card)
  players: T.ArrayOf T.Integer
  lead: T.Integer

  play_cards: (player_id, cards) ->
    @players.push player_id
    @cards.push cards

  last_play: ->
    return util_m.last @cards
}




Turnbase.state {
  players: (T.ArrayOf Player)
  undealt_cards: (T.ArrayOf MCard)
  # team 0: players 0 and 2
  # team 1: players 1 and 3
  # team_points[r][t] = points for team t in round r
  team_points: (T.ArrayOf (T.ArrayOf T.Integer))
  points_to_win: T.Integer

  draw: (player_id, num_cards) ->
    assert num_cards <= @undealt_cards.length
    cards = @undealt_cards.splice 0, num_cards
    for c in cards
      c.add_access player_id
      @players[player_id].cards.push c

  redeal: (rand = null) ->
    deck = logic.make_deck()
    deck = ((new MCard card) for card in deck)
    util_m.shuffle deck, rand
    @undealt_cards = deck
    for i in [0...4]
      @players[i].cards = []
      @draw i, 8
      @players[i].cards.sort logic.comparator

  team_total: (team_num) ->
    assert team_num in [0, 1]
    ret = 0
    for score in @team_points
      ret += score[team_num]
    return ret

  is_game_over: ->
    return ((@team_total 0) >= @points_to_win or
            (@team_total 1) >= @points_to_win)

  is_player_out: (id) -> @players[id].is_out()
}


Turnbase.setup {
  options: [
    Turnbase.option 'Play to %{points_to_win} points', {
      points_to_win: Turnbase.select {
        500: 500
        1000: 1000
      }, 1000
    }
  ]

  init: (initial_data) ->
    {num_players} = initial_data
    if num_players isnt 4
      throw new Error "Must play with 4 players"

    players = []
    for i in [0...4]
      players.push new Player {
        cards: []
        tichu_level: logic.CAN_GRAND
        points_taken: []
      }
    # TODO: should we redeal before returning this?
    return {
      players: players
      team_points: []
      undealt_cards: []
      points_to_win: initial_data.points_to_win ? 1000
    }
}

Turnbase.main ->
  @LOG 'Game started.'
  while not @is_game_over()
    # reset state of each player
    for player in @players
      player.tichu_level = logic.CAN_GRAND
      player.points_taken = []
      player.cards = []

    @redeal @RANDOM.rand
    await @ENTER_MODE 'GrandTichu', {}, defer()

    await @ENTER_MODE 'Pass', {
      to_pass: (null for _ in [0...4])
    }, defer()

    cur_turn = 0
    for i in [0...4]
      for card in @players[i].cards
        if card.suit is 'mahjong'
          cur_turn = i

    await @ENTER_MODE 'Play', {
      cur_turn: cur_turn
      last_player: null
      mahjong_wish: null
      cur_trick:
        cards: []
        players: []
        lead: cur_turn # TODO: this serves no purpose currently
      players_out: []
    }, defer()
  @GAME_OVER()

Turnbase.mode 'Play', {
  cur_turn: T.Integer
  last_player: (T.Nullable T.Integer)
  mahjong_wish: (T.Nullable T.Integer)
  cur_trick: Trick
  players_out: (T.ArrayOf T.Integer)

  _is_round_over: ->
    return true if @players_out.length >= 3
    if @players_out.length is 2
      [first, second] = @players_out
      return true if (first % 2) == (second % 2)
    return false

  _finalize_points: ->
    for player, idx in @players
      if player.cards.length > 0
        @players_out.push idx

    assert @players_out.length is 4
    [first, second] = @players_out.slice 0, 2
    onetwo = (first % 2) == (second % 2)
    round_pts = [0, 0]

    pts_collected = []
    # account for tichu
    for player, idx in @players
      team = (idx % 2)
      pts = 0
      if player.tichu_level is logic.TICHU
        pts += (if first is idx then 100 else -100)
      if player.tichu_level is logic.GRAND
        pts += (if first is idx then 200 else -200)
      round_pts[team] += pts
      pts_collected.push logic.points_value player.points_taken

    if onetwo
      round_pts[first % 2] += 200
      @team_points.push round_pts
      return

    last = @players_out[3]
    transfer = pts_collected[last]
    pts_collected[first] += transfer

    for pts, idx in pts_collected
      unless idx is last
        round_pts[idx % 2] += pts

    # give last player's hand points to opponent
    last_hand = @players[last].cards
    opp_team = (last + 1) % 2
    round_pts[opp_team] += logic.points_value last_hand


    @team_points.push round_pts

  # give points from current trick to specified player
  _give_points: (recipient) ->
    plays = @cur_trick.cards
    for play in plays
      for card in play
        if logic.is_points card
          @players[recipient].points_taken.push card

  # give the lead to the player given, and points of trick
  _give_lead: (player_id) ->
    # give points
    # did dragon win trick?
    last = @cur_trick.last_play()
    if last? and last[0].suit == 'dragon'
      opp1 = (player_id + 1) % 4
      opp2 = (player_id + 3) % 4
      recipient = null

      # TODO: log that dragon was automatically given
      if @is_player_out opp1
        recipient = opp2
      else if @is_player_out opp2
        recipient = opp1
      else
        await @ENTER_MODE 'PickDragon', {
          dragon_picker: player_id
        }, defer recipient
        console.log "Dragon given to #{recipient}"

      @_give_points recipient
    else
      @_give_points player_id

    # clear trick and give lead
    @cur_trick = new Trick {
      cards: []
      players: []
      lead: player_id
    }

    @last_player = null
    @cur_turn = player_id
    @_skip_out_players()

  # advance to next player who isn't out
  # possibly give lead
  _skip_out_players: ->
    for i in [1..4]
      # give lead. TODO: wait for bombs
      if @cur_turn == @last_player
        @_give_lead @last_player
      if @is_player_out(@cur_turn)
        @cur_turn = (@cur_turn + 1) % 4
      else
        return

  play: (to_play, phoenix_value, wish) ->
    types: [
      (T.ArrayOf T.Integer)
      (T.Nullable T.Integer)
      (T.Nullable T.Integer)
    ]
    validate: -> V.check [
        # TODO: check that mahjong was played if wishing
        [(wish is null) or (wish in [2..14]), "Invalid mahjong wish!"]
        =>
          hand = @players[@PLAYER].cards
          played = ((util_m.clone hand[idx]) for idx in to_play)
          for c in played
            continue unless c.suit is 'phoenix'
            if not phoenix_value?
              return V.r false, "Must specify phoenix value"
            c.value = phoenix_value

          played_bomb = logic.is_bomb played
          unless played_bomb or @PLAYER is @cur_turn
            return V.r false, "Out of turn!"
          last = util_m.last @cur_trick.cards
          # this also handles the case where last is null
          if not (logic.is_playable_over played, last)
            return V.r false, "Not playable!"
          # check mahjong wish
          # you can bomb "before" your turn (or on someone else's) to avoid wish
          if played_bomb
            return V.r true
          # no wish?
          unless @mahjong_wish?
            return V.r true
          csmw = logic.can_satisfy_mahjong_wish
          unless csmw last, hand, @mahjong_wish
            return V.r true
          dsmw = logic.does_satisfy_mahjong_wish
          if dsmw played, @mahjong_wish
            return V.r true
          return V.r false, "Must satisfy wish!"
      ]
    execute: ->
      hand = @players[@PLAYER].cards
      new_hand = []
      played = []

      for card, idx in hand
        if idx in to_play
          c = MCard.unmask card
          if c.suit is 'phoenix'
            c.value = phoenix_value
          played.push c
        else
          new_hand.push card
      @players[@PLAYER].cards = new_hand
      played.sort logic.comparator
      @cur_trick.play_cards @PLAYER, played
      @LOG "%{#{@PLAYER}} plays #{tichu_helpers_m.hand_as_text played}"

      # not allowed to tichu anymore
      if @players[@PLAYER].tichu_level == logic.CAN_TICHU
        @players[@PLAYER].tichu_level = logic.NO_TICHU

      dsmw = logic.does_satisfy_mahjong_wish
      if @mahjong_wish? and (dsmw played, @mahjong_wish)
        @mahjong_wish = null
      if wish?
        @mahjong_wish = wish

      @last_player = @PLAYER
      @cur_turn = (@PLAYER + 1) % 4

      if @is_player_out @PLAYER
        console.log @PLAYER, 'went out'
        @players_out.push @PLAYER

      if @_is_round_over()
        # if not a 1-2, pretend the trick was just taken
        # for the sake of points
        if @players_out.length isnt 2
          # TODO: XXXXXX RELIES ON THE FACT THAT THE AWAIT IN
          # _give_lead WILL NOT GET CALLED IN THIS SITUATION
          @_give_lead @PLAYER
        @_finalize_points()
        return @LEAVE_MODE()

      if played[0]?.suit == 'dog'
        # TODO: display that dog has been played?
        @_give_lead ((@last_player + 2) % 4)

      @_skip_out_players()


  pass: ->
    types: []
    validate: -> V.check [
        [@PLAYER is @cur_turn, "Out of turn! (cur turn: #{@cur_turn})"]
        [@last_player?, "You have the lead, must play"]
        =>
          return (V.r true) if not @mahjong_wish?
          csmw = logic.can_satisfy_mahjong_wish
          cards = @players[@PLAYER].cards
          if (csmw @cur_trick.last_play(), cards, @mahjong_wish)
            return V.r false, "You must satisfy wish!"
          return V.r true
      ]
    execute: ->
      @LOG "%{#{@PLAYER}} passed."
      @cur_turn = (@cur_turn + 1) % 4
      @_skip_out_players()
      # if @last_player == @cur_turn
      #   @_give_lead @cur_turn

  tichu: ->
    types: []
    validate: -> V.check [
      [@players[@PLAYER].tichu_level == logic.CAN_TICHU, "can't tichu!"]
    ]
    execute: ->
      @players[@PLAYER].tichu_level = logic.TICHU
      @LOG "%{#{@PLAYER}} calls Tichu!"
}

Turnbase.mode 'Pass', {
  to_pass: (T.ArrayOf (T.Nullable (T.ArrayOf T.MInteger)))

  tichu: ->
    types: []
    validate: -> V.check [
      [@players[@PLAYER].tichu_level == logic.CAN_TICHU, "can't tichu!"]
      ]
    execute: ->
      @players[@PLAYER].tichu_level = logic.TICHU
      # unpass all the cards
      for p in [0...4]
        @to_pass[p] = null
      @LOG "%{#{@PLAYER}} calls Tichu!"

  pass: (cards) ->
    types: [(T.ArrayOf T.Integer)]
    validate: -> V.check [
      [not @to_pass[@PLAYER]?, "Already passed"]
      [cards.length is 3, "Must pass 3 cards"]
      # TODO: hard-coded 14 as the hand size
      [(util_m.all (0 <= idx and idx < 14 for idx in cards)), "Invalid pass!"]
      => ((V.distinct V.Number) cards)
      ]
    execute: ->
      @to_pass[@PLAYER] = []
      for n in cards
        masked_n = new T.MInteger n
        masked_n.add_access @PLAYER
        @to_pass[@PLAYER].push masked_n
      @LOG "%{#{@PLAYER}} finished passing."

      for pass in @to_pass
        if not pass?
          return

      # everyone has passed
      to_receive = ([] for i in [0...4])
      for i in [0...4]
        # get the cards from other players' passes
        for offset in [1,2,3]
          # the card we get was index 2, 1, 0, respectively
          other_player = (i + offset) % 4
          idx = @to_pass[other_player][3 - offset].get()
          card = @players[other_player].cards[idx]
          card.add_access i
          to_receive[i].push card

      # take cards
      for i in [0...4]
        passed = (x.get() for x in @to_pass[i].slice())
        passed.sort (util_m.by_value)
        passed.reverse()
        for idx in passed
          @players[i].cards.splice idx, 1

      # give cards
      for i in [0...4]
        util_m.concat @players[i].cards, to_receive[i]

      return @LEAVE_MODE()
}

Turnbase.mode 'PickDragon', {
  dragon_picker: T.Integer
  pick: (offset) ->
    types: [T.Integer]
    validate: -> V.check [
      [@PLAYER == @dragon_picker, "not your dragon pick!"]
      [offset is 1 or offset is 3, "invalid dragon pick!"]
    ]
    execute: ->
      recipient = (@dragon_picker + offset) % 4
      @LOG "%{#{@PLAYER}} gives dragon to %{#{recipient}}."
      return @LEAVE_MODE recipient
}

Turnbase.mode 'GrandTichu', {
  # TODO: make it so that action order doesn't affect next 6
  grand: ->
    types: []
    validate: -> V.check [
      [@players[@PLAYER].num_cards() == 8, "can't grand any more"]
    ]
    execute: ->
      @draw @PLAYER, 6
      player = @players[@PLAYER]

      player.cards.sort logic.comparator
      player.tichu_level = logic.GRAND
      @LOG "%{#{@PLAYER}} calls Grand Tichu!"

      for p in @players
        if p.num_cards() isnt 14
          return
      return @LEAVE_MODE()

  next_cards: ->
    types: []
    validate: -> V.check [
      [@players[@PLAYER].num_cards() == 8, "can't grand any more"]
    ]
    execute: ->
      @draw @PLAYER, 6
      player = @players[@PLAYER]

      player.cards.sort logic.comparator
      player.tichu_level = logic.CAN_TICHU

      for p in @players
        if p.num_cards() isnt 14
          return
      return @LEAVE_MODE()
}
