class TableReaper
  constructor: (@_table_router, @_mins_delay) ->

  run: ->
    do_reap = =>
      @reap()
      setTimeout do_reap, (@_mins_delay * 60000)
    do_reap()

  reap: ->
    console.log 'performing table reap cycle'

    table_info = @_table_router.list_tables()
    for info in table_info
      tid = info.tid
      table_server = @_table_router.get_table tid

      # TODO: implement game_over()
      if table_server.is_removable()
        console.log 'reaping', tid
        @_table_router.delete_table tid

exports.TableReaper = TableReaper