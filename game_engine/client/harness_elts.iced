util_m = require 'shared/util.iced'
{T} = require 'shared/T/T.iced'
{make_elt} = require 'client/lib/html_util.iced'

# TODO: use make_elt

is_grid = (x) ->
  type_name = x.constructor._name
  if not type_name?
    return false
  if util_m.startswith type_name, "Grid<"
    return true
  if util_m.startswith type_name, "MGrid<"
    return true
  return false

identify_type = (x) ->
  if not x? then return 'null'
  if typeof x in ['string', 'number', 'boolean']
    return typeof x
  if T.is_masked x then return 'masked'
  if x instanceof Array then return 'array'
  if is_grid x then return 'grid'
  return 'struct'

make_display = (x, name = null) ->
  type = identify_type x
  if type in ['null', 'string', 'number', 'boolean', 'masked']
    return new PrimitiveDisplay type, x, name
  if type is 'array'
    return new ArrayDisplay x, name
  if type is 'grid'
    return new GridDisplay x, name
  if type is 'struct'
    return new StructDisplay x, name
  throw new Error "Unhandled type #{type}!"


class TabularElement
  TMPL = '''
  <div class="spec-container">
    <div class="spec-array-header">
      <div class="standard-table-cell">
        <div class="spec-array-dropdown">+</div>
      </div>
      <div class="spec-header-text standard-table-cell"></div>
    </div>
    <div class="spec-table-container">
      <table class="spec-array-table"></table>
    </div>
  </div>
  '''
  constructor: ->
    @_elt = $ TMPL
    @_table = (@_elt.find '> > .spec-array-table')
    @_table_container = (@_elt.find '> .spec-table-container')
    @_table_container.hide()

    @_shown = false
    @_dropdown = (@_elt.find '> > > .spec-array-dropdown')

    (@_elt.find '> .spec-array-header').click =>
      @_shown = not @_shown
      if @_shown
        @_dropdown.html '&ndash;'
      else
        @_dropdown.html '+'
      @_table_container.slideToggle 300

  set_header: (text) ->
    @_elt.find('> > .spec-header-text').text text
  # TODO: allow setting to empty
  # set_empty: (is_empty) ->
  #   if is_empty
  #     @_dropdown.html '' # TODO
  elt: -> @_elt
  table: -> @_table


class PrimitiveDisplay
  LABEL_TMPL = '''
    <div class="spec-container">
      <div class="spec-struct-key"></div>
      <div class="spec-struct-value"></div>
    </div>
  '''
  constructor: (@type, value, @name = null) ->
    @_inner = $ "<div></div>"
    if @name?
      @_outer = $ LABEL_TMPL
      (@_outer.find '.spec-struct-key').text @name
      (@_outer.find '.spec-struct-value').append @_inner
    @update value

  update: (@value) ->
    @_inner.text (if @type is 'masked' then '<masked>' else @value)

  elt: -> if @name? then @_outer else @_inner

class ArrayDisplay
  constructor: (value, @name = null) ->
    @type = 'array'
    @value = []
    @_cells = []
    @_tabular = new TabularElement()
    @update value

  update: (@value) ->
    text = (if @name? then "#{@name}:" else "<array>") + " [#{@value.length}]"
    @_tabular.set_header text

    # TODO: ideally, we'd do a smarter array diff, but this is good
    # enough most of the time
    for item, idx in @value
      if idx < @_cells.length
        elt = @_cells[idx].elt
        if identify_type(item) is elt.type
          console.log 'soft array update', item
          elt.update item
        else
          console.log 'mismatch', identify_type(item), elt.type
          elt.elt().remove()
          @_cells[idx].elt = make_display item
          @_cells[idx].container.find('td.entry').append @_cells[idx].elt.elt()
      else
        tr = $ "<tr><td>#{idx}:</td><td class=\"entry\"></td></tr>"
        elt = make_display item
        tr.find('td.entry').append(elt.elt())
        @_tabular.table().append(tr)
        @_cells.push {container: tr, elt: elt}

    for idx in [@value.length...@_cells.length]
      @_cells[idx].container.remove()
    @_cells = @_cells.slice(0, @value.length)

  elt: -> @_tabular.elt()


class GridDisplay
  constructor: (value, @name = null) ->
    @type = 'grid'
    @_tabular = new TabularElement()
    @update value

  update: (@value) ->
    text = if @name? then "#{@name}:" else "<grid>"
    text += " [#{@value.width} x #{@value.height}]"
    @_tabular.set_header text

    # TODO: look into making less destructive update
    @_tabular.table().empty()
    for r in [0...@value.height]
      tr = $ "<tr></tr>"
      for c in [0...@value.width]
        td = $("<td></td>").css({'min-width': 20, 'height': 20})
        entry = @value.get r, c
        if entry?
          td.append (make_display entry).elt()
        tr.append td
      @_tabular.table().append tr

  elt: -> @_tabular.elt()


class StructDisplay
  constructor: (value) ->
    console.log 'making struct', value
    @type = 'struct'
    @_elt = $ "<div></div>"
    @_fields = {}
    @update value

  update: (@value) ->
    for k, elt of @_fields
      if k not of @value
        @_fields[k].elt().remove()
        delete @_fields[k]
        continue

      if identify_type(@value[k]) is elt.type
        console.log 'soft struct update', k
        elt.update @value[k]
      else
        @_fields[k] = make_display @value[k]
        elt.elt().remove()
        @_elt.append @_fields[k].elt()

    for k, v of @value
      # TODO: show access somehow
      if k is '_access' then continue
      if typeof v is 'function' then continue
      if k of @_fields then continue

      elt = make_display v, k
      @_fields[k] = elt
      @_elt.append elt.elt()

  elt: -> @_elt


exports.make_display = make_display