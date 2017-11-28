{struct} = require 'shared/T/struct.iced'
{T} = require 'shared/T/primitive.iced'

Grid = (type) ->
  ret = struct ("Grid<#{type._name}>"), {
    width: T.Integer
    height: T.Integer
    contents: T.ArrayOf (T.Nullable type)

    in_range: (r, c) ->
      return (0 <= r and r < @height and 0 <= c and c < @width)
    get: (r, c) ->
      return @contents[r * @width + c]
    set: (r, c, val) ->
      @contents[r * @width + c] = val
  }, {
    loaders: [
      (json) ->
        if json.contents?
          return false
        {@width, @height} = json
        @contents = (null for _ in [0...(@width * @height)])
        return true
    ]
  }
  return ret

exports.Grid = Grid