assert = require 'assert'

util_m = require 'shared/util.iced'
logic = require 'games/tichu/tichu_logic.iced'

class OneVsOneEvaluator
    constructor: () ->


    # given my_hand and indices_mask, returns a bunch of info related to the potential play.
    extract_play_info_from_indices_mask: (my_hand, indices_mask) ->
        play_indices = []
        play_cards = []
        phoenix_index = null
        for i in [0...my_hand.length]
            include_ith_card = ((1 << i) & indices_mask) > 0
            if include_ith_card
                play_indices.push(i)
                play_cards.push(my_hand[i])
                if my_hand[i].suit == 'phoenix'
                    phoenix_index = i
        return [play_indices, play_cards, phoenix_index]

    # i is an index into all 2^(my_hand.length) possible hands.
    # start at 1... passing (e.g. playing no cards) will be handled separately
    iterate_plays: (my_hand, last_play, fn) ->
        for mask in [1...(1 << my_hand.length)]
            [play_indices, play_cards, phoenix_index] = @extract_play_info_from_indices_mask(my_hand, mask)
            # phoenix could be any # between 1 and Ace (14), inclusive
            # k is possible phoenix values
            if phoenix_index?
                for k in [1..14]
                    # TODO: a little sketchy to modify this value in place, but it works
                    play_cards[phoenix_index].value = k
                    if logic.is_playable_over(play_cards, last_play)
                        fn(play_indices, play_cards, k)
            else if logic.is_playable_over(play_cards, last_play)
                fn(play_indices, play_cards, null)

    # assuming only 2 players (me and an opponent) are left, compute the opponent's hand
    opponent_hand: (my_hand, cards_remaining) ->
      their_hand = []
      for card in cards_remaining
        in_my_hand = false
        for c in my_hand
          if c.suit == card.suit and (c.value == card.value or c.suit == 'phoenix' or card.suit == 'phoenix')
            in_my_hand = true
            break
        if not in_my_hand
          their_hand.push(card)
      return their_hand

    # returns whether player_id is eligible to start using the 1v1 bot.
    eligible: (game_state, player_id, cards_remaining) ->
      partner_id = (player_id + 2) % 4
      opponent1_id = (player_id + 1) % 4
      opponent2_id = (player_id + 3) % 4

      if game_state.cur_turn != player_id
        return false

      if not game_state.players[partner_id].is_out?
        return false

      if game_state.players[player_id].is_out?
        return false

      if game_state.players[opponent1_id].is_out? == game_state.players[opponent2_id].is_out?
        return false

      # now compute my_hand and their_hand
      my_hand = game_state.players[player_id].cards.slice()
      their_hand = opponent_hand(my_hand, cards_remaining)
      return hands_are_valid(my_hand, their_hand)


    hands_are_valid: (my_hand, their_hand) ->
        # TODO: assert there are no bombs in either hand?
        assert my_hand.length <= 6
        assert their_hand.length <= 6
        for card in my_hand
            assert card.suit != 'mahjong'
            assert card.suit != 'dog'
        for card in their_hand
            assert card.suit != 'mahjong'
            assert card.suit != 'dog'
        # todo... handle dogs and bombs and mahjong wishes?.

    # returns the max. point differential (e.g. my final points minus their final points),
    # given optimal play by both sides) that
    # I can win in this scenario, along with the best play (card indices).
    #
    # current_trick is a list of the plays in the current trick
    # if it's empty, then I have the lead.
    evaluate_scenario: (my_hand, their_hand, current_trick, {my_points, their_points, partner_out_first}, depth = 0) ->
        last_play = if current_trick.length > 0
            current_trick[current_trick.length-1]
        else
            null

        s = ('  ' for _ in [0...depth])
        s = s.join('')
        # console.log s, my_hand, their_hand, last_play, 'partner out', partner_out_first
        # console.log s, 'pts', my_points, their_points

        # if opponent just ran out of cards.....
        if their_hand.length == 0
            assert last_play?

            # console.log s, 'ran out', my_points, their_points

            # definitely no possibility of 1-2
            trick_value = logic.points_value_of_trick(current_trick)
            ended_on_dragon = last_play? and last_play[0].suit == 'dragon'
            if ended_on_dragon
                my_points += trick_value
            else
                their_points += trick_value

            their_points += logic.points_value(my_hand)
            if not partner_out_first
                their_points += my_points
                my_points = 0

            # console.log s, 'after gather', my_points, their_points
            return [my_points - their_points, null]

            ## assume that opponent played the "last_play"

        best_points_so_far = null
        best_play_so_far = null # {play:play_idxs, phx:phx_val}

        handle_playable = (play_indices, play_cards, phx_val) =>
            new_trick = current_trick.slice()
            new_trick.push(play_cards)

            my_new_hand = (my_hand[i] for i in [0...my_hand.length] when i not in play_indices)
            #console.log play_indices, my_new_hand, my_hand
            assert my_new_hand.length < my_hand.length

            [their_best_points, _] = @evaluate_scenario(
                their_hand,
                my_new_hand,
                new_trick,
                {
                    my_points: their_points,
                    their_points: my_points,
                    partner_out_first: not partner_out_first
                }, depth + 1)
            if not best_points_so_far? or -their_best_points > best_points_so_far
                best_points_so_far = -their_best_points
                best_play_so_far = {play:play_indices, phx:phx_val}

        @iterate_plays(my_hand, last_play, handle_playable)

        # If I have the lead, I must play something
        if not last_play?
            return [best_points_so_far, best_play_so_far]

        # If I pass, the trick is over. score...
        # ignore bombs here.
        trick_value = logic.points_value_of_trick(current_trick)
        ended_on_dragon = last_play? and last_play[0].suit == 'dragon'

        my_point_delta = if ended_on_dragon then trick_value else 0
        their_point_delta = trick_value - my_point_delta

        [their_best_points, _] = @evaluate_scenario(
            their_hand, my_hand, [],
            {
                my_points: their_points + their_point_delta,
                their_points: my_points + my_point_delta,
                partner_out_first: not partner_out_first
            }, depth + 1)

        if not best_points_so_far? or -their_best_points > best_points_so_far
            best_points_so_far = -their_best_points
            best_play_so_far = {play:[], phx:null}
        return [best_points_so_far, best_play_so_far]

exports.OneVsOneEvaluator = OneVsOneEvaluator


# test_util_m = require 'games/tichu/logic_tests/test_util.coffee'

# evaluator = new OneVsOneEvaluator

# hand1 = test_util_m.make_hand [
#     '2H', '10H', '10S', 'JC', 'QD',
# #    '2H', '3H', '4S', '10S', '10D', 'KC'
# ]
# hand2 = test_util_m.make_hand [
# #    '5C',
# #    '5C', '10H',
#     '5C', '10H', 'phoenix',
# #    '5C', '10H', '8C', '8D', 'QD'
# ]


# class OneVsOneState
#     constructor: (@my_hand, @their_hand, @cur_trick, {
#         @my_points, @their_points, @partner_out_first
#         }) ->

#     trick_value_to_winner: (trick) ->
#         val = logic.points_value_of_trick trick
#         last_play = util_m.last trick
#         if last_play? and last_play[0].suit is 'dragon'
#             val = -val
#         return val

#     do_play: (play_idxs, phx_val) ->
#         # TODO: modifies in place for now
#         if play_idxs.length == 0 # pass
#             trick_value = logic.points_value_of_trick(@cur_trick)
#             last_play = util_m.last @cur_trick
#             @cur_trick = []

#             ended_on_dragon = last_play? and last_play[0].suit == 'dragon'
#             if ended_on_dragon
#                 @my_points += trick_value
#             else
#                 @their_points += trick_value
#             return

#         play = (@my_hand[idx] for idx in [0...@my_hand.length] when idx in play_idxs)
#         for card in play
#             if card.suit is 'phoenix'
#                 card.value = phx_val
#         new_hand = (@my_hand[idx] for idx in [0...@my_hand.length] when idx not in play_idxs)
#         console.log 'play', play
#         @cur_trick.push play
#         @my_hand = new_hand

#     reverse: ->
#         return (new OneVsOneState @their_hand, @my_hand, @cur_trick, {
#             my_points: @their_points, their_points: @my_points,
#             partner_out_first: not @partner_out_first
#             })

#     print: ->
#         console.log 'my hand', (test_util_m.hand_to_str_arr @my_hand)
#         console.log 'my pts', @my_points
#         console.log 'their hand', (test_util_m.hand_to_str_arr @their_hand)
#         console.log 'their pts', @their_points
#         console.log 'cur_trick:'
#         for play in @cur_trick
#             console.log '  ', (test_util_m.hand_to_str_arr play)
#         console.log 'partner out first', @partner_out_first


# state = new OneVsOneState hand1, hand2, [], {
#     my_points: 0, their_points: 0, partner_out_first: true
# }

# while hand1.length > 0 and hand2.length > 0
#     console.log '----'

#     [value, play_info] = (evaluator.evaluate_scenario state.my_hand, state.their_hand,
#         state.cur_trick, state)
#     state.print()
#     if not play_info?
#         break
#     [play_idxs, phx_val] = play_info
#     console.log 'value:', value
#     state.do_play(play_idxs, phx_val)
#     state = state.reverse()
