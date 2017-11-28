exports.extend = (a, b) ->
  for k, v of b
    if k of a
      throw new Error "Refuse to clobber old property #{k} of #{a}"
    a[k] = v

# concatenates to_append to l (without making a new copy)
exports.concat = (l, to_append) ->
  to_append.forEach ((x) -> @push x), l

exports.last = (l) ->
  return (if l.length > 0 then l[l.length - 1] else null)

exports.all = (l) ->
  for elt in l
    return false if not elt
  return true

exports.rand_int = rand_int = (n) ->
  return Math.floor(Math.random() * n)

exports.rand_choice = rand_choice = (arr) ->
  return arr[rand_int arr.length]

exports.clamp = clamp = (x, lower, upper) ->
  return Math.min (Math.max x, lower), upper

exports.clone = clone = (item) ->
  return JSON.parse(JSON.stringify(item))

# Shuffle array in-place using Fisher-Yates shuffle algorithm.
exports.shuffle = shuffle = (array, rand = null) ->
  rand ?= Math.random
  i = array.length - 1
  while i > 0
    j = Math.floor(rand() * (i + 1))
    temp = array[i]
    array[i] = array[j]
    array[j] = temp
    i--
  return

# for sorting numbers
exports.by_value = (a, b) -> a - b
# for sorting strings
exports.lexicographically = (a, b) ->
  if a < b then return -1
  if a > b then return 1
  return 0

exports.ordinal = (n) ->
  if (n % 10 is 1) and (n % 100 isnt 11)
    return n + 'st'
  if (n % 10 is 2) and (n % 100 isnt 12)
    return n + 'nd'
  if (n % 10 is 3) and (n % 100 isnt 13)
    return n + 'rd'
  return n + 'th'
# throws an error if the input is not a valid integer
exports.parse_int = (s) ->
  ret = parseInt s
  if (isNaN ret) or (ret + '').length isnt s.length
    throw new Error "#{s} is not an integer"
  return ret

exports.startswith = startswith = (s, prefix) ->
  return (s.slice 0, prefix.length) is prefix
exports.endswith = endswith = (s, ending) ->
  return (s.substring (s.length - ending.length), s.length) is ending