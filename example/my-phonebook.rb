#!/usr/bin/env ruby

begin
  require 'cmd'
rescue LoadError
  require File.dirname(__FILE__) + '/../lib/cmd'
end
require 'yaml'

class PhoneBook < Cmd
  STORAGE = File.expand_path('~/.phonebook')
  
  doc :list, "List names in phone book."
  def do_list
    write @data.names
  end

  doc :add, "Add an entry into the phone book."
  def do_add
    
  end

  protected

    def setup
      create_storage_if_need_be
      File.open(STORAGE) do |file|
        @data = YAML.load(file)
      end
    rescue
      write "Unable to load phonebook - #$!"
      exit
    end

    def create_storage_if_need_be
      File.open(STORAGE, 'w') unless File.exists?(STORAGE)
    end

    def postloop
      save_data
    end

    def save_data
      write 'Saving...'
      File.open(STORAGE, 'w') do |file|
        file.write YAML.dump(@data)
      end
    end
end

class PhoneBookListing

  attr_accessor :name, :number, :type 
  def initialize
  end
end

class PhoneBookList
  def initialize
    @list = []
  end

  def <<(listing)
    @list.push listing
  end

  def names
    @list.map {|listing| listing.name}.sort
  end
end

PhoneBook.run
