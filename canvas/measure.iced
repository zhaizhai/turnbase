# global test ctx
g_ctx = null

# this should be set upon creation of the canvas element
exports.set_ctx = (_ctx) ->
  g_ctx = _ctx

exports.text_width = (txt, styles) ->
  g_ctx.font = "#{styles.size}pt #{styles.font}"
  return (g_ctx.measureText txt).width

