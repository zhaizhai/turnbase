{T, struct} = require 'shared/T/T.iced'

X = struct 'X', {
  a: T.MString
}

new X {
  a: 'hello'
}