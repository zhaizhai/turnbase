class Point
  constructor: (@x, @y) ->

  dist: (other) ->
    dx = @x - other.x
    dy = @y - other.y
    return Math.sqrt (dx * dx + dy * dy)

  plus: (other) ->
    return new Point (@x + other.x), (@y + other.y)

  minus: (other) ->
    return new Point (@x - other.x), (@y - other.y)

  scale: (r) ->
    return new Point (@x * r), (@y * r)

exports.space_rectangle = (width, height, n) ->
  # TODO: for now assume starts at bottom
  rect = [(new Point 0, height), (new Point width, height),
          (new Point width, 0), (new Point 0, 0)]
  segments = []
  for pt, i in rect
    next = rect[(i + 1) % 4]
    segments.push [pt, next]

  total_dist = 2 * width + 2 * height
  step = total_dist / n

  ret = []
  cur_seg = 0
  cur_pos = width / 2
  for i in [0...n]
    dist_left = step
    while dist_left > 0
      [start, end] = segments[cur_seg]
      d = start.dist end

      if dist_left <= d - cur_pos
        cur_pos += dist_left
        offset = (end.minus start).scale (cur_pos / d)
        ret.push (start.plus offset)
        break

      dist_left -= (d - cur_pos)
      cur_pos = 0
      cur_seg = (cur_seg + 1) % 4

  [last] = ret.splice (ret.length - 1), 1
  ret = [last].concat ret
  return ret
