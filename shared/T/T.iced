util_m = require 'shared/util.iced'
{extend} = util_m

mask_m = require 'shared/T/mask.iced'
struct_m = require 'shared/T/struct.iced'
primitive_m = require 'shared/T/primitive.iced'
grid_m = require 'shared/T/grid.iced'

T =
  Grid: grid_m.Grid
extend T, primitive_m.T
extend T, struct_m.T
extend T, mask_m.T

# TODO: hacky way of combining all of these
primitive_m.T = struct_m.T = mask_m.T = T
exports.T = T
exports.struct = struct_m.struct