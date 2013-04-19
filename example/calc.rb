#!/usr/bin/env ruby

begin
  require 'cmd'
rescue LoadError
  require File.dirname(__FILE__) + '/../lib/cmd'
end
require 'mathn'

class StackUnderflowError < StandardError; end

class Calculator < Cmd
  VALUE = /^-?\d+(\/\d+)?$/

  prompt_with     :prompt_command

  shortcut  '.',  :pop
  shortcut  'x',  :swap

  shortcut  '+',  :add
  shortcut  '*',  :multiply
  shortcut  '-',  :subtract
  shortcut  '/',  :divide

  doc :clear,     "Clears the contents of the stack"
  doc :dup,       "Pushes the value of the stack's top item"
  doc :pop,       "Removes the top item from the stack and displays its value"
  doc :push,      "Pushes the values passed onto the stack"
  doc :swap,      "Swaps the order of the stack's top 2 items"

  doc :add,       "Pops 2 items, adds them, and pushes the result"
  doc :multiply,  "Pops 2 items, multiplies them, and pushes the result"
  doc :subtract,  "Pops 2 items, subtracts the topmost, and pushes the result"
  doc :divide,    "Pops 2 items, divides by the topmost, and pushes the result"

  handle StackUnderflowError, 'Stack underflow'
  handle ZeroDivisionError,   'Division by zero'

  def do_clear;       setup                     end
  def do_dup;         push peek                 end
  def do_pop;         print_value pop           end
  def do_push(values) push *values              end
  def do_swap;        swap                      end

  def do_add;         push pop + pop            end
  def do_multiply;    push pop * pop            end
  def do_subtract;    swap; push pop - pop      end
  def do_divide;      swap; push pop / pop      end

protected

  def setup;          @stack = []               end
  def peek;           @stack.last or underflow  end
  def pop;            @stack.pop  or underflow  end
  def push(*values)   @stack += values          end
  def swap;           top = pop; push top, pop  end
  def underflow;      raise StackUnderflowError end

  def print_value(value)
    puts "=> #{value.inspect}"
  end

  def contents
    return "(empty)" if @stack.empty?
    @stack.inspect
  end
  
  def command_missing(command, values)
    return super unless command =~ VALUE
    do_push values.unshift(eval(command))
  end

  def prompt_command
    "#{self.class.name}#{contents}> "
  end

  def tokenize_args(args)
    return args unless current_command =~ VALUE or current_command == "push"
    args.to_s.split(/ +/).inject([]) do |a, v|
      raise ArgumentError, "bad integer value #{v}" unless v =~ VALUE
      a << eval(v)
    end
  end
end

Calculator.run
