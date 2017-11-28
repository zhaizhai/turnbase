# turn card value into a short string
exports.hash_card = hash_card = (card) ->
  if card.suit in ['dragon', 'phoenix', 'mahjong', 'dog']
    return card.suit
  else
    return "#{card.suit}#{card.value}"

# turn entire hand of cards into an object/hashtable
exports.hash_hand = hash_hand = (hand) ->
  res = {}
  for card in hand
    res[@hash_card card] = 1
  return res

VALUE_STRINGS = ('' + i for i in [2..10])
VALUE_STRINGS.splice 0, 0, null, null
VALUE_STRINGS = VALUE_STRINGS.concat ['J', 'Q', 'K', 'A']

exports.card_as_text = card_as_text = (card) ->
  specials = {
    dog: 'Dog', dragon: 'Dragon',
    phoenix: 'P', mahjong: 1
  }
  if card.suit of specials
    return specials[card.suit]
  return VALUE_STRINGS[card.value]

exports.hand_as_text = hand_as_text = (hand) ->
  cards_text = (card_as_text card for card in hand)
  return cards_text.join ' '


exports.encode_val = encode_val = (val) ->
  return VALUE_STRINGS[val]

exports.decode_val = decode_val = (str) ->
  str = str.toUpperCase()
  for s, idx in VALUE_STRINGS
    if s is str
      return idx
  return ''
