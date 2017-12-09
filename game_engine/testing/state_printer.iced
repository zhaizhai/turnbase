util_m = require 'shared/util.iced'
{T} = require 'shared/T/T.iced'

# TODO: this should probably be built into the type system somehow
is_grid = (x) ->
  type_name = x.constructor._name
  if not type_name?
    return false
  if util_m.startswith type_name, "Grid<"
    return true
  if util_m.startswith type_name, "MGrid<"
    return true
  return false

class StatePrinter
  pad_to = (s, padded_length) ->
    extra = padded_length - s.length
    ret = s + ' '.repeat(extra)
    return ret

  @_print: (x) ->
    if not x? then return ['null']
    mtypes = ['MStringContainer', 'MIntegerContainer',
              'MNumberContainer', 'MBooleanContainer']
    if x.constructor?._name in mtypes
      x = x.get()
    if typeof x is 'string'
      return ["\"#{x}\""]
    if typeof x in ['number', 'boolean']
      return ["#{x}"]

    if T.is_masked x then return ['#']
    if x instanceof Array
      return @_print_array x
    if is_grid x
      return @_print_grid x
    # TODO: check that x is actually a struct?
    return @_print_struct x

  @_print_array: (x) ->
    ret = ["["]
    for item, idx in x
      lines = @_print item
      for line, line_idx in lines
        if line_idx is lines.length - 1 and idx < x.length - 1
          ret.push ('  ' + line + ',')
        else
          ret.push ('  ' + line)
    ret.push "]"
    return ret

  @_print_struct: (x) ->
    # TODO: intelligently compress if each item is short
    items = []
    for k, v of x.constructor._fields
      lines = @_print x[k]
      if lines.length is 1
        lines[0] = "#{k}: #{lines[0]}"
      else
        for line, idx in lines
          lines[idx] = '  ' + line
        lines.splice 0, 0, "#{k}:"
      items.push lines

    MAX_LINE_LENGTH = 50
    idx = 0
    while idx < items.length - 1
      cur = items[idx]
      next = items[idx + 1]
      if (cur.length is 1 and next.length is 1 and
          cur[0].length + next[0].length <= MAX_LINE_LENGTH)
        items[idx] = [cur[0] + ", " + next[0]]
        items.splice (idx + 1), 1
      else
        idx++

    if items.length is 1 and items[0].length is 1
      return ['{ ' + items[0][0] + ' }']

    ret = ['{']
    for lines in items
      for line in lines
        ret.push ('  ' + line)
    ret.push '}'
    return ret

  @_print_grid: (grid) ->
    [w, h] = [grid.width, grid.height]
    [cell_w, cell_h] = [0, 0]

    entry_lines = []
    for r in [0...h]
      for c in [0...w]
        entry = (grid.get r, c)
        # Don't print null's since often most entries are null
        lines = if entry? then (@_print entry) else ['  ']

        max_w = Math.max (s.length for s in lines)...
        max_h = lines.length
        cell_w = Math.max cell_w, max_w
        cell_h = Math.max cell_h, max_h
        entry_lines.push {max_w, max_h, lines}

    separator_row = '-'.repeat(cell_w) + '+'
    separator_row = '+' + separator_row.repeat(w)

    idx = 0
    ret = [separator_row]
    for r in [0...h]
      rows = ('|' for _ in [0...cell_h])
      for c in [0...w]
        {lines, max_w, max_h} = entry_lines[idx]
        top_pad = Math.ceil((cell_h - max_h) / 2)
        bottom_pad = Math.floor((cell_h - max_h) / 2)
        left_pad = Math.ceil((cell_w - max_w) / 2)
        right_pad = Math.floor((cell_w - max_w) / 2)

        for i in [0...top_pad]
          rows[i] += ' '.repeat(cell_w) + '|'

        for i in [top_pad...(cell_h - bottom_pad)]
          line = lines[i - top_pad]
          rows[i] += ' '.repeat(left_pad)
          rows[i] += pad_to line, max_w
          rows[i] += ' '.repeat(right_pad) + '|'

        for i in [(cell_h - bottom_pad)...cell_h]
          rows[i] += ' '.repeat(cell_w) + '|'
        idx++

      ret = ret.concat rows
      ret.push separator_row
    return ret

  @print: (state) ->
    lines = @_print state
    return lines.join('\n')

exports.StatePrinter = StatePrinter