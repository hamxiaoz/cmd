#!/usr/bin/env ruby

begin
  require 'cmd'
rescue LoadError
  require File.dirname(__FILE__) + '/../lib/cmd'
end
require 'yaml'

class PhoneBook < Cmd
  PHONEBOOK_FILE = File.expand_path('~/.phonebook')

  doc :add, 'Add an entry (ex: add Sam, 312-555-1212)'
  def do_add(args)
    name, number = args.to_s.split(/, +/)
    @numbers[name.strip] = number
  end
  shortcut '+', :add
  
  doc :find, 'Look up an entry (ex: find Sam)'
  def do_find(name)
    name.to_s.strip!
    if @numbers[name]
      print_name_and_number(name, @numbers[name])
    else
      puts "#{name} isn't in the phone book"
    end
  end

  doc :list, 'List all entries'
  def do_list
    @numbers.sort.each do |name, number|
      print_name_and_number(name, number)
    end
  end

  doc :delete, 'Remove an entry'
  def do_delete(name)
    @numbers.delete(name) || write("No entry for '#{name}'")
  end
  
protected

  def setup
    @numbers = get_store || {}
  end

  def complete_find(line)
    completion_grep(@numbers.keys.sort, line)
  end
  
  def print_name_and_number(*args)
    puts "%-25s %s" % args
  end

  def postloop
    File.open(PHONEBOOK_FILE, 'w') {|store| store.write YAML.dump(@numbers)}
  end

  def get_store
    File.open(PHONEBOOK_FILE) {|store| YAML.load(store)} rescue nil 
  end

  def command_missing(command, args)
    do_find(command)
  end
end

PhoneBook.run
