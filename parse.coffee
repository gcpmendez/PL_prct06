# parse.js
# Parser for Simplified JavaScript written in Simplified JavaScript
# From Top Down Operator Precedence
# http://javascript.crockford.com/tdop/index.html
# Douglas Crockford
# 2010-06-26

make_parse = ->
  scope = undefined
  symbol_table = {}
  token = undefined
  tokens = undefined
  token_nr = undefined

  itself = ->
    this

  original_scope = 
    define: (n) ->
      t = @def[n.value]
      if typeof t == 'object'
        n.error if t.reserved then 'Already reserved.' else 'Already defined.'
      @def[n.value] = n
      n.reserved = false
      n.nud = itself
      n.led = null
      n.std = null
      n.lbp = 0
      n.scope = scope
      n
    find: (n) ->
      e = this
      o = undefined
      loop
        o = e.def[n]
        if o and typeof o != 'function'
          return e.def[n]
        e = e.parent
        if !e
          o = symbol_table[n]
          return if o and typeof o != 'function' then o else symbol_table['(name)']
      return
    pop: ->
      scope = @parent
      return
    reserve: (n) ->
      if n.arity != 'name' or n.reserved
        return
      t = @def[n.value]
      if t
        if t.reserved
          return
        if t.arity == 'name'
          n.error 'Already defined.'
      @def[n.value] = n
      n.reserved = true
      return

  new_scope = ->
    s = scope
    scope = Object.create(original_scope)
    scope.def = {}
    scope.parent = s
    scope

  advance = (id) ->
    a = undefined
    o = undefined
    t = undefined
    v = undefined
    if id and token.id != id
      token.error 'Expected \'' + id + '\'.'
    if token_nr >= tokens.length
      token = symbol_table['(end)']
      return
    t = tokens[token_nr]
    token_nr += 1
    v = t.value
    a = t.type
    if a == 'name'
      o = scope.find(v)
    else if a == 'operator'
      o = symbol_table[v]
      if !o
        t.error 'Unknown operator.'
    else if a == 'string' or a == 'number'
      o = symbol_table['(literal)']
      a = 'literal'
    else
      t.error 'Unexpected token.'
    token = Object.create(o)
    token.from = t.from
    token.to = t.to
    token.value = v
    token.arity = a
    token

  expression = (rbp) ->
    left = undefined
    t = token
    advance()
    left = t.nud()
    while rbp < token.lbp
      t = token
      advance()
      left = t.led(left)
    left

  statement = ->
    n = token
    v = undefined
    if n.std
      advance()
      scope.reserve n
      return n.std()
    v = expression(0)
    if !v.assignment and v.id != '('
      v.error 'Bad expression statement.'
    advance ';'
    v

  statements = ->
    a = []
    s = undefined
    loop
      if token.id == '}' or token.id == '(end)'
        break
      s = statement()
      if s
        a.push s
    if a.length == 0 then null else if a.length == 1 then a[0] else a

  block = ->
    t = token
    advance '{'
    t.std()

  original_symbol = 
    nud: ->
      @error 'Undefined.'
      return
    led: (left) ->
      @error 'Missing operator.'
      return

  symbol = (id, bp) ->
    s = symbol_table[id]
    bp = bp or 0
    if s
      if bp >= s.lbp
        s.lbp = bp
    else
      s = Object.create(original_symbol)
      s.id = s.value = id
      s.lbp = bp
      symbol_table[id] = s
    s

  constant = (s, v) ->
    x = symbol(s)

    x.nud = ->
      scope.reserve this
      @value = symbol_table[@id].value
      @arity = 'literal'
      this

    x.value = v
    x

  infix = (id, bp, led) ->
    s = symbol(id, bp)
    s.led = led or (left) ->
      @first = left
      @second = expression(bp)
      @arity = 'binary'
      this
    s

  infixr = (id, bp, led) ->
    s = symbol(id, bp)
    s.led = led or (left) ->
      @first = left
      @second = expression(bp - 1)
      @arity = 'binary'
      this
    s

  assignment = (id) ->
    infixr id, 10, (left) ->
      if left.id != '.' and left.id != '[' and left.arity != 'name'
        left.error 'Bad lvalue.'
      @first = left
      @second = expression(9)
      @assignment = true
      @arity = 'binary'
      this

  prefix = (id, nud) ->
    s = symbol(id)
    s.nud = nud or ->
      scope.reserve this
      @first = expression(70)
      @arity = 'unary'
      this
    s

  stmt = (s, f) ->
    x = symbol(s)
    x.std = f
    x

  symbol '(end)'
  symbol '(name)'
  symbol ':'
  symbol ';'
  symbol ')'
  symbol ']'
  symbol '}'
  symbol ','
  symbol 'else'
  constant 'true', true
  constant 'false', false
  constant 'null', null
  constant 'pi', 3.141592653589793
  constant 'Object', {}
  constant 'Array', []
  symbol('(literal)').nud = itself

  symbol('this').nud = ->
    scope.reserve this
    @arity = 'this'
    this

  assignment '='
  assignment '+='
  assignment '-='
  infix '?', 20, (left) ->
    @first = left
    @second = expression(0)
    advance ':'
    @third = expression(0)
    @arity = 'ternary'
    this
  infixr '&&', 30
  infixr '||', 30
  infixr '===', 40
  infixr '!==', 40
  infixr '<', 40
  infixr '<=', 40
  infixr '>', 40
  infixr '>=', 40
  infix '+', 50
  infix '-', 50
  infix '*', 60
  infix '/', 60
  infix '.', 80, (left) ->
    @first = left
    if token.arity != 'name'
      token.error 'Expected a property name.'
    token.arity = 'literal'
    @second = token
    @arity = 'binary'
    advance()
    this
  infix '[', 80, (left) ->
    @first = left
    @second = expression(0)
    @arity = 'binary'
    advance ']'
    this
  infix '(', 80, (left) ->
    a = []
    if left.id == '.' or left.id == '['
      @arity = 'ternary'
      @first = left.first
      @second = left.second
      @third = a
    else
      @arity = 'binary'
      @first = left
      @second = a
      if (left.arity != 'unary' or left.id != 'function') and left.arity != 'name' and left.id != '(' and left.id != '&&' and left.id != '||' and left.id != '?'
        left.error 'Expected a variable name.'
    if token.id != ')'
      loop
        a.push expression(0)
        if token.id != ','
          break
        advance ','
    advance ')'
    this
  prefix '!'
  prefix '-'
  prefix 'typeof'
  prefix '(', ->
    e = expression(0)
    advance ')'
    e
  prefix 'function', ->
    a = []
    new_scope()
    if token.arity == 'name'
      scope.define token
      @name = token.value
      advance()
    advance '('
    if token.id != ')'
      loop
        if token.arity != 'name'
          token.error 'Expected a parameter name.'
        scope.define token
        a.push token
        advance()
        if token.id != ','
          break
        advance ','
    @first = a
    advance ')'
    advance '{'
    @second = statements()
    advance '}'
    @arity = 'function'
    scope.pop()
    this
  prefix '[', ->
    a = []
    if token.id != ']'
      loop
        a.push expression(0)
        if token.id != ','
          break
        advance ','
    advance ']'
    @first = a
    @arity = 'unary'
    this
  prefix '{', ->
    a = []
    n = undefined
    v = undefined
    if token.id != '}'
      loop
        n = token
        if n.arity != 'name' and n.arity != 'literal'
          token.error 'Bad property name.'
        advance()
        advance ':'
        v = expression(0)
        v.key = n.value
        a.push v
        if token.id != ','
          break
        advance ','
    advance '}'
    @first = a
    @arity = 'unary'
    this
  stmt '{', ->
    new_scope()
    a = statements()
    advance '}'
    scope.pop()
    a
  stmt 'var', ->
    a = []
    n = undefined
    t = undefined
    loop
      n = token
      if n.arity != 'name'
        n.error 'Expected a new variable name.'
      scope.define n
      advance()
      if token.id == '='
        t = token
        advance '='
        t.first = n
        t.second = expression(0)
        t.arity = 'binary'
        a.push t
      if token.id != ','
        break
      advance ','
    advance ';'
    if a.length == 0 then null else if a.length == 1 then a[0] else a
  stmt 'if', ->
    advance '('
    @first = expression(0)
    advance ')'
    @second = block()
    if token.id == 'else'
      scope.reserve token
      advance 'else'
      @third = if token.id == 'if' then statement() else block()
    else
      @third = null
    @arity = 'statement'
    this
  stmt 'return', ->
    if token.id != ';'
      @first = expression(0)
    advance ';'
    if token.id != '}'
      token.error 'Unreachable statement.'
    @arity = 'statement'
    this
  stmt 'break', ->
    advance ';'
    if token.id != '}'
      token.error 'Unreachable statement.'
    @arity = 'statement'
    this
  stmt 'while', ->
    advance '('
    @first = expression(0)
    advance ')'
    @second = block()
    @arity = 'statement'
    this
  (source) ->
    tokens = source.tokens()
    token_nr = 0
    new_scope()
    advance()
    s = statements()
    advance '(end)'
    scope.pop()
    s
