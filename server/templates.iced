fs = require 'fs'
path = require 'path'

iced_compiler = require 'iced-coffee-script'
browserify = require 'browserify'
mustache = require 'mustache'
through = require 'through'

util_m = require 'shared/util.iced'

{SimpleLock} = require 'shared/synchro.iced'

ALIAS_MAPPING =
  '&jquery': '/lib/jquery-2.1.4.min.js'
  '&markdown': '/lib/markdown.min.js'

ICED_RUNTIME = '''
(function() {
    var __slice = [].slice;

  window.iced = {
      Deferrals: (function() {
          function _Class(_arg) {
              this.continuation = _arg;
              this.count = 1;
              this.ret = null;
            }

        _Class.prototype._fulfill = function() {
              if (!--this.count) {
                  return this.continuation(this.ret);
                }
              };

        _Class.prototype.defer = function(defer_params) {
              var _this = this;
              ++this.count;
              return function() {
                  var inner_params, _ref;
                  inner_params = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
                  if (defer_params != null) {
                      if ((_ref = defer_params.assign_fn) != null) {
                          _ref.apply(null, inner_params);
                        }
                      }
                    return _this._fulfill();
                  };
              };

        return _Class;

      })(),
      findDeferral: function() {
          return null;
        },
        trampoline: function(_fn) {
            return _fn();
          }
      };

}).call(this);
'''

class JsCache
  COMPILED_JS_DIR = __dirname + '/../static/compiled_js'

  transform_fn = (file) ->
    data = ''
    write = (buf) ->
      data += buf
    end = ->
      if (util_m.endswith file, '.js')
        @queue data
        return @queue null

      try
        compiled_src = iced_compiler.compile data, {runtime: 'none'}
      catch e
        # TODO: handle error
        console.error "Couldn't compile #{file}"
        throw e

      @queue compiled_src
      @queue null
    return (through write, end)

  # TODO: this is a bit hacked together, maybe we can do something
  # better later
  with_compile_lock = (fn) ->
    ret = (args..., cb) ->
      await @_compile_lock.acquire defer()
      args.push (cb_args...) =>
        @_compile_lock.release()
        return cb cb_args...
      fn.apply @, args
    return ret

  constructor: ->
    # nodemon should automatically restart if files change
    @_cache = {}
    @_compile_lock = new SimpleLock

  get_compiled: with_compile_lock (path, cb) ->
    is_iced = util_m.endswith path, '.iced'
    if is_iced
      path = path.substring 0, (path.length - '.iced'.length)

    if @_cache[path]?
      return cb null, @_cache[path]

    abs_path = "client/#{path}" + (if is_iced then '.iced' else '.coffee')
    await @_compile abs_path, defer err, js_string
    return cb err if err

    # create parent dirs if necessary
    components = path.split '/'
    components.pop()
    dir_path = "#{COMPILED_JS_DIR}"
    for comp in components
      dir_path += '/' + comp
      await fs.exists dir_path, defer exists
      if not exists
        await fs.mkdir dir_path, defer err
        return cb err if err

    long_js_path = "#{COMPILED_JS_DIR}/#{path}.js"
    await fs.writeFile long_js_path, js_string, defer err
    return cb err if err

    console.log "Compiled #{path} to #{long_js_path}"

    js_path = "/compiled_js/#{path}.js"
    @_cache[path] = js_path
    return cb null, js_path

  _compile: (path, cb) ->
    b = browserify()
    b.transform transform_fn
    b.add path
    await b.bundle defer err, js_string
    if err
      console.log "Error while compiling #{path}:", err
      return cb err

    # # doesn't work for now b/c of iced bug, we'll just add our own
    # # iced runtime
    # iced_runtime = iced_compiler.compile '', {
    #   runtime: 'window',
    #   runforce: true
    # }
    # js_string = iced_runtime + '\n\n' + js_string
    js_string = ICED_RUNTIME + '\n' + js_string
    return cb null, js_string

# TODO: get rid of this global variable
_global_cache = new JsCache

parse_js_deps = (js_deps, cb) ->
  js_deps ?= []
  ret = []
  for path in js_deps
    if path[0] is '&'
      ret.push {js_path: ALIAS_MAPPING[path]}
    else
      await _global_cache.get_compiled path, defer err, js_path
      return cb err if err
      ret.push {js_path}
  return cb null, ret

parse_css_deps = (css_deps) ->
  return [] if not css_deps?
  ret = []
  for css_path in css_deps
    ret.push {css_path}
  return ret

# js_deps and css_deps are special params
render_template = (tmpl_path, params, cb) ->
  await parse_js_deps params.js_deps, defer err, parsed_deps
  return cb err if err
  params.js_deps = parsed_deps

  params.css_deps = parse_css_deps params.css_deps

  static_dir = __dirname + '/../static'
  await fs.readFile (static_dir + '/' + tmpl_path), 'utf8', defer err, data
  return cb err if err

  rendered = mustache.render(data, params)
  return cb null, rendered

exports.render_template = render_template
exports.JsCache = JsCache
