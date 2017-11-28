{T} = require 'shared/T/T.iced'
{V} = require 'shared/T/validation.iced'

req =
  params:
    tid: 't0'
  body:
    cursors: {}
    cid: 'c0'
res = V.validate_request req, {
  params:
    tid: T.String
  body:
    cursor: T.Object
    cid: T.String
  }

console.log res