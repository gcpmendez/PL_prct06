'use strict'
# tokens.js
# 2010-02-23
# Produce an array of simple token objects from a string.
# A simple token object contains these members:
#      type: 'name', 'string', 'number', 'operator'
#      value: string or number value of the token
#      from: index of first character of the token
#      to: index of the last character + 1
# Comments are ignored.

RegExp::bexec = (str) ->
  i = @lastIndex
  m = @exec(str)
  if m and m.index == i
    return m
  null

String::tokens = ->
  from = undefined
  # The index of the start of the token.
  i = 0
  # The index of the current character.
  n = undefined
  # The number value.
  m = undefined
  # Matching
  result = []
  # An array to hold the results.
  WHITES = /\s+/g
  ID = /[a-zA-Z_]\w*/g
  NUM = /\b\d+(\.\d*)?([eE][+-]?\d+)?\b/g
  STRING = /('(\\.|[^'])*'|"(\\.|[^"])*")/g
  ONELINECOMMENT = /\/\/.*/g
  MULTIPLELINECOMMENT = /\/[*](.|\n)*?[*]\//g
  TWOCHAROPERATORS = /(===|!==|[+][+=]|-[-=]|=[=<>]|[<>][=<>]|&&|[|][|])/g
  ONECHAROPERATORS = /([-+*\/=()&|;:,<>{}[\]])/g
  # May be some character is missing?
  tokens = [
    WHITES
    ID
    NUM
    STRING
    ONELINECOMMENT
    MULTIPLELINECOMMENT
    TWOCHAROPERATORS
    ONECHAROPERATORS
  ]
  # Make a token object.

  make = (type, value) ->
    {
      type: type
      value: value
      from: from
      to: i
    }

  getTok = ->
    str = m[0]
    i += str.length
    # Warning! side effect on i
    str

  # Begin tokenization. If the source string is empty, return nothing.
  if !this
    return
  # Loop through this text
  while i < @length
    tokens.forEach (t) ->
      t.lastIndex = i
      return
    # Only ECMAScript5
    from = i
    # Ignore whitespace and comments
    if m = WHITES.bexec(this) or (m = ONELINECOMMENT.bexec(this)) or (m = MULTIPLELINECOMMENT.bexec(this))
      getTok()
    else if m = ID.bexec(this)
      result.push make('name', getTok())
    else if m = NUM.bexec(this)
      n = +getTok()
      if isFinite(n)
        result.push make('number', n)
      else
        make('number', m[0]).error 'Bad number'
    else if m = STRING.bexec(this)
      result.push make('string', getTok().replace(/^["']|["']$/g, ''))
    else if m = TWOCHAROPERATORS.bexec(this)
      result.push make('operator', getTok())
      # single-character operator
    else if m = ONECHAROPERATORS.bexec(this)
      result.push make('operator', getTok())
    else
      throw 'Syntax error near \'' + @substr(i) + '\''
  result
