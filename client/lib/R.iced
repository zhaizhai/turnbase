assert = require 'assert'
R = {}

R.Image = (handle, data) ->
  return ['img', handle, data]

image_load = (img, cb) ->
  img.onload = ->
    cb null
  img.onerror = (err) ->
    cb err

class ResourceLoader
  KNOWN_TYPES = ['img']

  # TODO: this resource loading API is far from solidified
  constructor: (raw_res_list) ->
    @_resources_by_type = {}
    for [type, handle, data] in raw_res_list
      assert type in KNOWN_TYPES
      unless type of @_resources_by_type
        @_resources_by_type[type] = {}

      if handle of @_resources_by_type[type]
        throw new Error "duplicate entries for handle #{handle} of type #{type}"
      @_resources_by_type[type][handle] = data

  # TODO: maybe we don't want to load all of them at once
  load_images: (cb) ->
    all_imgs = @_resources_by_type['img']
    await
      for k, v of all_imgs
        img = new Image
        img.src = v.url
        image_load img, defer err
        all_imgs[k] = if err then err else img
    return cb null

  get_readonly: (type, handle) ->
    if type not of @_resources_by_type
      throw new Error "unknown type #{type}"
    if handle not of @_resources_by_type[type]
      throw new Error "unknown handle #{handle}"
    return @_resources_by_type[type][handle]

  # TODO: will this be slow?
  get: (type, handle) ->
    ret = @get_readonly type, handle
    return (JSON.parse (JSON.stringify ret))

  get_img: (img_handle) ->
    return @get_readonly 'img', img_handle


_shared_loader = null

R.init = (raw_res_list, cb) ->
  _shared_loader = new ResourceLoader raw_res_list
  await _shared_loader.load_images defer err
  return cb err

R.get = (type, handle) ->
  if not _shared_loader?
    throw new Error "resource loader not initialized"
  return (_shared_loader.get type, handle)

R.get_img = (img_handle) ->
  if not _shared_loader?
    throw new Error "resource loader not initialized"
  return (_shared_loader.get_img img_handle)


exports.R = R