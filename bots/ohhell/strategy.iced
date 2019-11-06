assert = require 'assert'
util_m = require 'shared/util.iced'
ohhell_logic_m = require 'games/ohhell/ohhell_logic.iced'

class FivePlayerStrategy
  group_cards = (hand) ->
    card_info = {C: [], D: [], H: [], S: []}
    for card in hand
      card_info[card.suit].push card
    suits_by_length = ['C', 'D', 'H', 'S']
    suits_by_length.sort (a, b) ->
      return card_info[a].length - card_info[b].length
    card_info.suits_by_length = suits_by_length
    return card_info

  # TODO: Incorporate information about other players, e.g.  whether
  # they have already hit their bid. Note that this requires some
  # logic to correspond player ids with the trick.
  constructor: (@hand, bid_left) ->
    @card_info = group_cards @hand
    @deficit = @_get_expected_tricks() - bid_left

  _get_expected_tricks: ->
    ret = 0
    for card in @hand
      if card.value >= 13
        ret += 1
    return ret

  decide_lead: ->
    {suits_by_length} = @card_info

    # Play non-trump winner if possible.
    for suit in suits_by_length
      if suit is 'S' then continue
      for card in @card_info[suit]
        if card.value >= 13
          return card

    # Play shortest non-trump if possible.
    for suit in suits_by_length
      if suit is 'S' then continue
      cards_for_suit = @card_info[suit]
      if cards_for_suit.length > 0
        return cards_for_suit[0]

    for card in @hand
      assert card.suit is 'S'
    # Only trumps left, play highest if we have a deficit, otherwise
    # lowest.
    return if @deficit > 0 then @hand[@hand.length - 1] else @hand[0]

  _play_under: (card, candidates) ->
    candidates_under = []
    for c in candidates
      if c.value >= 13
        # We should never duck with A or K, if we can help it.
        continue
      if c.suit is card.suit
        if c.value < card.value
          candidates_under.push c
      else if c.suit isnt 'S'
        candidates_under.push c

    if candidates_under.length is 0
      # Impossible to play under. Then probably good to play highest
      # possible card as we are unintentionally taking a trick.
      return util_m.last candidates
    if @deficit > 0
      return candidates_under[0]
    else
      return util_m.last candidates_under

  decide_play: (trick) ->
    lead_suit = trick[0].suit
    winner_idx = ohhell_logic_m.winner_idx_of_trick trick
    # Card that is winning the trick so far
    winning = trick[winner_idx]
    cards_in_suit = @card_info[lead_suit]

    if lead_suit is 'S'
      # Lead is trump. It means leader only has trumps.
      if cards_in_suit.length is 0
        # We have no trumps, so don't expect to win any further
        # tricks. Play anything.
        return @hand[0]
      if winning.value >= 13
        # Winning is either A or K. Don't try to beat it.
        return @_play_under winning, cards_in_suit

      # TODO: Logic below is probably pretty bad. Hopefully we can
      # replace it by exhaustive search for endgame.
      highest = util_m.last cards_in_suit
      if highest.value >= 13
        # If we have A or K, play it.
        return highest
      return @_play_under winning, cards_in_suit

    else
      # Lead is non-trump.
      cards_in_suit = @card_info[lead_suit]

      if winning.suit is lead_suit and winning.value >= 13
        # Expected winner A or K was played. Try to duck.
        candidates = if cards_in_suit.length > 0 then cards_in_suit else @hand
        # TODO: Add logic for when it's impossible to play under.
        return @_play_under winning, candidates

      if cards_in_suit.length > 0
        # We must follow suit.
        highest = util_m.last cards_in_suit
        # If we have A or K, play it. TODO: Consider adding logic in
        # case the trick has been trumped. However, you are not
        # supposed to trump if an A or K is still out.
        if highest.value >= 13 then return highest
        # Try to win if we have a deficit. This should usually not
        # come into play I think.
        return if @deficit > 0 then highest else cards_in_suit[0]

      # We're void.
      if winning.suit is 'S'
        # The trick was trumped. Don't try to win.
        # TODO: Prefer to discard short suits
        return @_play_under winning, @hand
      else if @deficit > 0
        # No one trumped, and we have deficit. Try to win by trumping.
        if @card_info.S.length > 0
          # TODO: bad logic here, fix later
          return @card_info.S[0]
        else
          return @_play_under winning, @hand

      # We have no deficit, so try to discard highest card in shortest
      # non-trump suit that isn't ace or king.
      for suit in @card_info.suits_by_length
        if suit is 'S' then continue
        non_ace_king = (c for c in @card_info[suit] when c.value < 13)
        to_discard = util_m.last non_ace_king
        if to_discard?
          return to_discard
      # Apparently we only have trump left, just trump with highest.
      return util_m.last @hand

exports.FivePlayerStrategy = FivePlayerStrategy