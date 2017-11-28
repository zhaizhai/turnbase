mustache_m = require 'mustache'

exports.make_elt = make_elt = (tmpl, params) ->
  html = mustache_m.to_html tmpl, params
  return $ html

exports.make_button = make_button = (text) ->
  return make_elt '''
    <button class="standard-button">{{text}}</button>
  ''', {text}

exports.make_select = make_select = (choices) ->
  sel = $ '''<select class="standard-select"></select>'''
  for k, v of choices
    opt_elt = ($ '<option></option>').val(v).html(k)
    sel.append opt_elt
  return sel

exports.make_table = make_table = (entries) ->
  ret = $ '<div class="standard-table-container"></div>'
  for row in entries
    row_elt = $ '<div class="standard-table-row"></div>'
    for elt in row
      cell = $ '<div class="standard-table-cell"></div>'
      if elt?
        cell.append elt
      row_elt.append cell
    ret.append row_elt
  return ret
