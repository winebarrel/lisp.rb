#!/usr/bin/env ruby

# This program is Ruby port of Lispy
# Lispy (c) Peter Norvig, 2010-14; See http://norvig.com/lispy.html

require 'forwardable'
require 'readline'

class LispSymbol
  attr_reader :name
  alias to_s name

  def initialize(name)
    @name = name.to_s
  end
end

def LispSymbol(name)
  LispSymbol.new(name)
end

def parse(program)
  read_from_tokens(tokenize(program))
end

def tokenize(s)
  s.gsub('(', ' ( ').gsub(')',' ) ').sub(/\A\s+/, '').sub(/\s+\z/, '').split(/\s+/)
end

def read_from_tokens(tokens)
  if tokens.length == 0
    raise 'unexpected EOF while reading'
  end

  token = tokens.shift

  if '(' == token
    list = []

    while tokens[0] != ')'
      list << read_from_tokens(tokens)
    end

    tokens.shift

    list
  elsif ')' == token
    raise 'unexpected )'
  else
    atom(token)
  end
end

def atom(token)
  if token =~ /\A".*"\z/
    eval(token)
  else
    [Integer, Float, LispSymbol].each do |clazz|
      begin
        break send(clazz.to_s, token)
      rescue ArgumentError
      end
    end
  end
end

def standard_env
  env = Env.new

  Math.methods(false).each do |name|
    env[LispSymbol(name)] = Math.method(name)
  end

  %i(> < >= <= =).each do |op|
    env[LispSymbol(op)] = op.to_proc
  end

  %i(+ - * /).each do |op|
    env[LispSymbol(op)] = -> (*x) { x.inject(&op.to_proc) }
  end

  {
    abs:        -> (x) { x.abs },
    append:     :+.to_proc,
    apply:      -> (function, args) { function.call(*args) },
    'begin' =>  -> (*x) { x.last },
    car:        -> (x) { x.first },
    cdr:        -> (x) { x.slice(1..-1) },
    cons:       -> (x, y) { [x] + y },
    eq?:        -> (x, y) { x.equal?(y) },
    equal?:     :==.to_proc,
    length:     -> (x) { x.length },
    list:       -> (*x) { x },
    list?:      -> (x) { x.is_a?(Array) },
    map:        -> (f, x) { x.map {|i| f.call(i) } },
    max:        -> (x) { x.max },
    min:        -> (x) { x.min },
    not:        -> (x) { !x },
    null?:      -> (x) { x.empty? },
    number?:    -> (x) { x.is_a?(Numeric) },
    print:      -> (x) { puts lispstr(x) },
    procedure?: -> (x) { x.respond_to?(:call) },
    round:      -> (x) { x.to_f.round },
    symbol?:    -> (x) { x.is_a?(String) },
  }.each do |name, func|
    env[LispSymbol(name)] = func
  end

  env
end

class Env
  extend Forwardable

  def initialize(parms = [], args = [], outer = nil)
    @hash = Hash.new
    parms = parms.map(&:to_s)
    @hash.update(Hash[*parms.zip(args).flatten(1)])
    @outer = outer
  end

  def [](var)
    @hash[var.to_s]
  end

  def []=(var, val)
    @hash[var.to_s] = val
  end

  def find(var)
    var = var.to_s

    if @hash.has_key?(var)
      self
    elsif @outer
      @outer.find(var)
    else
      raise "unbound variable: #{var}"
    end
  end
end

$global_env = standard_env

def repl(prompt = 'lisp.rb> ')
  while buf = Readline.readline(prompt, true)
    begin
      val = evaluate(parse(buf))
      puts lispstr(val) if val
    rescue => e
      $stderr.puts ([e.message] + e.backtrace).join("\n\tfrom")
    end
  end
end

def lispstr(exp)
  case exp
  when Array
    '(' + exp.map {|i| lispstr(i) }.join(' ') + ')'
  when String
    exp.inspect
  else
    exp.to_s
  end
end

class Procedure
  def initialize(parms, body, env)
    @parms = parms.map {|i| LispSymbol(i) }
    @body = body
    @env = env
  end

  def call(*args)
    evaluate(@body, Env.new(@parms, args, @env))
  end
end

def evaluate(x, env = $global_env)
  if x.is_a?(LispSymbol)
    env.find(x)[x]
  elsif not x.is_a?(Array)
    x
  else
    case x[0].to_s
    when 'quote'
      x[1]
    when 'if'
      test, conseq, alt = x.values_at(1, 2, 3)

      if evaluate(test, env)
        exp = conseq
      else
        exp = alt
      end

      evaluate(exp, env)
    when 'define'
      var, exp = x.values_at(1, 2)
      var = LispSymbol(var)
      env[var] = evaluate(exp, env)
    when 'set!'
      var, exp = x.values_at(1, 2)
      var = LispSymbol(var)
      env.find(var)[var] = evaluate(exp, env)
    when 'lambda'
      parms, body = x.values_at(1, 2)
      Procedure.new(parms, body, env)
    else
      func = evaluate(x[0], env)
      args = x.slice(1..-1).map {|exp| evaluate(exp, env)  }
      func.call(*args)
    end
  end
end

if ARGV.length == 0
  repl
else
  evaluate(parse(ARGF.read))
end
