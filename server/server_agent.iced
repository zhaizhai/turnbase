


class Autoplay
  constructor: (@fn) ->
    @_pending = null

  # TODO: maybe also report how much longer?
  pending: -> @_pending?

  set: (delay_ms) ->
    @_pending = setTimeout @fn, delay_ms

  cancel: ->
    if @_pending?
      clearTimeout @_pending



class ServerAgent
  constructor: (@game_controller) ->

    @_pending_autoplay = null

    @on 'play', =>
      if @_pending_autoplay?
        clearTimeout @_pending_autoplay
        @_pending_autoplay = null

      @_pending_autoplay = setTimeout ,
        => # TODO

  autoplay: (player_id, cmd, args, delay_ms) ->



  