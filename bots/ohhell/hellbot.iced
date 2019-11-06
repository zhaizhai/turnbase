assert = require 'assert'
util_m = require 'shared/util.iced'

bidding_m = require 'bots/ohhell/bidding.iced'
{FivePlayerStrategy} = require 'bots/ohhell/strategy.iced'

bot_action = (gc, cmd, args, delay) ->
  await setTimeout defer(), delay
  await gc.submit_action cmd, args, defer err, res
  console.log err, res

class BidHandler
  constructor: (@gc, @player_id) ->
  _maybe_bid: ->
    if @gc.state().cur_turn isnt @player_id
      return
    if @gc.state().players_left_to_bid is 0
      # TODO: hack to make sure we don't try to bid right after last
      # bid is done
      return

    tricks_left = @gc.state().num_rounds - @gc.state().total_bid_so_far
    me = @gc.state().players[@player_id]
    bid = bidding_m.get_bid me.cards, tricks_left
    bot_action @gc, 'bid', [bid], 1000
  init: ->
    @_maybe_bid()
  action: ->
    @_maybe_bid()
  cleanup: ->

class PlayRoundHandler
  constructor: (@gc, @player_id) ->

  _maybe_play: ->
    if @gc.state().cur_turn isnt @player_id
      return
    if @gc.state().cur_trick.length is @gc.num_players()
      # TODO: hack to make sure we don't try to play right after last
      # card in trick is played.
      return

    me = @gc.state().players[@player_id]
    strategy = new FivePlayerStrategy me.cards, (me.bid - me.tricks_taken)
    to_play = if @gc.state().cur_trick.length is 0
      strategy.decide_lead()
    else
      strategy.decide_play @gc.state().cur_trick
    console.log "To play:", to_play

    for card, idx in me.cards
      if card.suit is to_play.suit and card.value is to_play.value
        return bot_action @gc, 'play', [idx], 1000
    assert false

  init: ->
    @_maybe_play()
  action: ->
    @_maybe_play()
  cleanup: ->

exports.AI = (gc, player_id) ->
  # TODO: prepare some state here that lasts over multiple tricks
  return {
    Bid: (new BidHandler gc, player_id)
    PlayRound: (new PlayRoundHandler gc, player_id)
  }
