READLINE_SUPPORTED = (require 'readline'; true) rescue false
require 'abbrev'

# A simple framework for writing line-oriented command interpreters, based 
# heavily on Python's {cmd.py}[http://docs.python.org/lib/module-cmd.html].
# 
# These are often useful for test harnesses, administrative tools, and
# prototypes that will later be wrapped in a more sophisticated interface.
# 
# A Cmd instance or subclass instance is a line-oriented interpreter
# framework.  There is no good reason to instantiate Cmd itself; rather,
# it's useful as a superclass of an interpreter class you define yourself
# in order to inherit Cmd's methods and encapsulate action methods.
class Cmd

  module ClassMethods
    @@docs      = {}
    @@shortcuts = {}
    @@handlers  = {}
    @@prompt    = '> '
    @@shortcut_table = {}
    
    # Set documentation for a command
    #
    #   doc :help, 'Display this help.'
    #   def do_help
    #     # etc
    #   end
    def doc(command, docstring = nil)
      docstring = docstring ? docstring : yield
      @@docs[command.to_s] = docstring
    end

    def docs
      @@docs
    end
    module_function :docs

    # Set what to do in the event that the given exception is raised.
    #
    #   handle StackOverflowError, :handle_stack_overflow
    #
    def handle(exception, handler)
      @@handlers[exception.to_s] = handler
    end
    module_function :handle

    # Sets what the prompt is. Accepts a String, a block or a Symbol.
    #
    # == Block 
    #
    #   prompt_with { Time.now }
    #
    # == Symbol
    #
    #   prompt_with :set_prompt
    #
    # == String
    #
    #   prompt_with "#{self.class.name}> "
    #
    def prompt_with(*p, &block)
      @@prompt = block_given? ? block : p.first
    end

    # Returns the evaluation of expression passed to prompt_with. Result has
    # +to_s+ called on it as Readline expects a String for its prompt.
    # XXX This could probably be more robust
    def prompt
      case @@prompt
      when Symbol 
          self.send @@prompt
      when Proc   
          @@prompt.call
      else         
          @@prompt
      end.to_s
    end
    module_function :prompt

    # Create a command short cut
    #
    #   shortcut '?', 'help'
    #   def do_help
    #     # etc
    #   end
    def shortcut(short, command)
      (@@shortcuts[command.to_s] ||= []).push short
      @@shortcut_table[short] = command.to_s
    end

    def shortcut_table
      @@shortcut_table
    end
    module_function :shortcut_table

    def shortcuts
      @@shortcuts
    end
    module_function :shortcuts

    def custom_exception_handlers
      @@handlers
    end
    module_function :custom_exception_handlers

    # Defines a method which returns all defined methods which start with the
    # passed in prefix followed by an underscore. Used to define methods to
    # collect things such as all defined 'complete' and 'do' methods.
    def define_collect_method(prefix)
      method = 'collect_' + prefix
      unless self.respond_to?(method) 
        define_method(method) do
          self.methods.grep(/^#{prefix}_/).map {|meth| meth[prefix.size + 1..-1]}
        end
      end
    end
  end
  extend  ClassMethods
  include ClassMethods

  @hide_undocumented_commands = nil
  class << self
    # Flag that sets whether undocumented commands are listed in the help
    attr_accessor :hide_undocumented_commands

    def run(intro = nil)
      new.cmdloop(intro)
    end
  end

  # STDIN stream used
  attr_writer :stdin

  # STDOUT stream used
  attr_writer :stdout

  # The current command
  attr_writer :current_command

  prompt_with :default_prompt

  def initialize
    @stdin, @stdout = STDIN, STDOUT
    @stop = false
    setup
  end 

  # Starts up the command loop
  def cmdloop(intro = nil)
    preloop
    write intro if intro
    begin
      set_completion_proc(:complete)
      begin
        execute_command
      # Catch ^C
      rescue Interrupt
        user_interrupt
      # I don't know why ZeroDivisionError isn't caught below...
      rescue ZeroDivisionError
        handle_all_remaining_exceptions(ZeroDivisionError)
      rescue => exception
        handle_all_remaining_exceptions(exception)
      end
    end until @stop
    postloop
  end
  alias :run :cmdloop

  shortcut '?', 'help'
  doc :help,  'This help message.' 
  def do_help(command = nil)
    if command
      command = translate_shortcut(command)
      docs.include?(command) ? print_help(command) : no_help(command)
    else
      documented_commands.each {|cmd| print_help cmd}
      print_undocumented_commands if undocumented_commands?
    end
  end

  # Called when the +command+ has no associated documentation, this could
  # potentially mean that the command is non existant
  def no_help(command)
    write "No help for command '#{command}'"
  end

  doc :exit,  'Terminate the program.' 
  def do_exit; stoploop end

  # Turns off readline even if it is supported
  def turn_off_readline
    @readline_supported = false
    self
  end

  protected

    def execute_command
      unless ARGV.empty?
        stoploop
        execute_line(ARGV * ' ')
      else
        execute_line(display_prompt(prompt, true))
      end
    end

    def handle_all_remaining_exceptions(exception)
      if exception_is_handled?(exception) 
        run_custom_exception_handling(exception) 
      else
        handle_exception(exception)
      end
    end

    def execute_line(command)
      postcmd(run_command(precmd(command)))
    end

    def stoploop
      @stop = true
    end

    # Indicates whether readline support is enabled
    def readline_supported?
      @readline_supported = READLINE_SUPPORTED if @readline_supported.nil?
      @readline_supported
    end

    # Determines if the given exception has a custome handler.
    def exception_is_handled?(exception)
      custom_exception_handler(exception)
    end

    # Runs the customized exception handler for the given exception.
    def run_custom_exception_handling(exception)
      case handler = custom_exception_handler(exception)
      when String
          write handler 
      when Symbol
          self.send(custom_exception_handler(exception))
      end
    end

    # Returns the customized handler for the exception
    def custom_exception_handler(exception)
      custom_exception_handlers[exception.to_s]
    end


    # Called at object creation. This can be treated like 'initialize' for sub
    # classes.
    def setup
    end

    # Exceptions in the cmdloop are caught and passed to +handle_exception+.
    # Custom exception classes must inherit from StandardError to be 
    # passed to +handle_exception+.
    def handle_exception(exception)
      raise exception
    end

    # Displays the prompt. 
    def display_prompt(prompt, with_history = true)
      line = if readline_supported?
        Readline::readline(prompt, with_history)
      else
        print prompt
        @stdin.gets
      end
      line.respond_to?(:strip) ? line.strip : line
    end

    # The current command.
    def current_command
      translate_shortcut @current_command
    end

    # Called when the user hits ctrl-C or ctrl-D. Terminates execution by default.
    def user_interrupt
      write 'Terminating' # XXX get rid of this
      stoploop
    end

    # XXX Not implementd yet. Called when a do_ method that takes arguments doesn't get any
    def arguments_missing
      write 'Invalid arguments'
      do_help(current_command) if docs.include?(current_command)
    end

    # A bit of a hack I'm afraid. Since subclasses will be potentially
    # overriding user_interrupt we want to ensure that it returns true so that
    # it can be called with 'and return'
    def interrupt
      user_interrupt or true
    end

    # Displays the help for the passed in command.
    def print_help(cmd)
      offset = docs.keys.longest_string_length
      write "#{cmd.ljust(offset)} -- #{docs[cmd]}"            + 
      (has_shortcuts?(cmd) ? " #{display_shortcuts(cmd)}" : '')
    end

    def display_shortcuts(cmd)
      "(aliases: #{shortcuts[cmd].join(', ')})"
    end

    # The method name that corresponds to the passed in command.
    def command(cmd)
      "do_#{cmd}".intern
    end

    # The method name that corresponds to the complete command for the pass in
    # command.
    def complete_method(cmd)
      "complete_#{cmd}".intern
    end

    # Call back executed at the start of the cmdloop.
    def preloop
    end
    
    # Call back executed at the end of the cmdloop.
    def postloop
    end

    # Receives line submitted at prompt and passes it along to the command
    # being called.
    def precmd(line)
      line
    end
    
    # Receives the returned value of the called command.
    def postcmd(line)
      line
    end
    
    # Called when an empty line is entered in response to the prompt.
    def empty_line
    end

    define_collect_method('do')
    define_collect_method('complete')

    # The default completor. Looks up all do_* methods.
    def complete(command)
      commands = completion_grep(command_list, command)
      if commands.size == 1
        cmd = commands.first
        set_completion_proc(complete_method(cmd)) if collect_complete.include?(cmd)
      end
      commands
    end

    # Lists of commands (i.e. do_* methods minus the 'do_' part).
    def command_list
      collect_do - subcommand_list
    end

    # Definitive list of shortcuts and abbreviations of a command.
    def command_lookup_table 
      return @command_lookup_table if @command_lookup_table
      @command_lookup_table = command_abbreviations.merge(shortcut_table)
    end

    # Returns lookup table of unambiguous identifiers for commands.
    def command_abbreviations
      return @command_abbreviations if @command_abbreviations
      @command_abbreviations = Abbrev::abbrev(command_list)
    end

    # List of all subcommands.
    def subcommand_list
      with_underscore, without_underscore = collect_do.partition {|command| command.include?('_')}
      with_underscore.find_all {|do_method| without_underscore.include?(do_method[/^[^_]+/])}
    end

    # Lists all subcommands of a given command.
    def subcommands(command)
      completion_grep(subcommand_list, translate_shortcut(command).to_s + '_')
    end

    # Indicates whether a given command has any subcommands.
    def has_subcommands?(command)
      !subcommands(command).empty?
    end

    # List of commands which are documented.
    def documented_commands
      docs.keys.sort
    end

    # Indicates whether undocummented commands will be listed by the help
    # command (they are listed by default).
    def undocumented_commands_hidden?
      self.class.hide_undocumented_commands  
    end

    def print_undocumented_commands
      return if undocumented_commands_hidden?
      # TODO perhaps do some fancy stuff so that if the number of undocumented
      # commands is greater than 80 cols or some such passed in number it
      # presents them in a columnar fashion much the way readline does by default
      write ' '
      write 'Undocumented commands'
      write '====================='
      write undocumented_commands.join(' ' * 4)
    end

    # Returns list of undocumented commands.
    def undocumented_commands
      command_list - documented_commands
    end

    # Indicates if any commands are undocumeted.
    def undocumented_commands?
      !undocumented_commands.empty?
    end

    # Completor for the help command.
    def complete_help(command)
      completion_grep(documented_commands, command)
    end

    def completion_grep(collection, pattern)
      collection.grep(/^#{Regexp.escape(pattern)}/)
    end

    # Writes out a message with newline.
    def write(*strings)
      # We want newlines at the end of every line, so don't join with "\n"
      strings.each do |string|
        @stdout.write string
        @stdout.write "\n"
      end
    end
    alias :puts :write

    # Writes out a message without newlines appended.
    def print(*strings)
      strings.each {|string| @stdout.write string}
    end

    shortcut '!', 'shell'
    doc :shell, 'Executes a shell.'
    # Executes a shell, perhaps should only be defined by subclasses.
    def do_shell(line)
      shell = ENV['SHELL']
      line ? write(%x(#{line}).strip) : system(shell)
    end

    # Takes care of collecting the current command and its arguments if any and
    # dispatching the appropriate command.
    def run_command(line)
      cmd, args = parse_line(line)
      sanitize_readline_history(line) if line
      unless cmd then empty_line; return end

      cmd = translate_shortcut(cmd)
      self.current_command = cmd
      set_completion_proc(complete_method(cmd)) if collect_complete.include?(complete_method(cmd))
      cmd_method = command(cmd)
      if self.respond_to?(cmd_method) 
        # Perhaps just catch exceptions here (related to arity) and call a
        # method that reports a generic error like 'invalid arguments'
        self.method(cmd_method).arity.zero? ? self.send(cmd_method) : self.send(cmd_method, tokenize_args(args)) 
      else                              
        command_missing(current_command, tokenize_args(args))
      end
    end

    # Receives the line as it was passed from the prompt (barring modification
    # in precmd) and splits it into a command section and an args section. The
    # args are by default set to nil if they are boolean false or empty then
    # joined with spaces. The tokenize method can be used to further alter the
    # args.
    def parse_line(line)
      # line will be nil if ctr-D was pressed
      user_interrupt and return if line.nil? 

      cmd, *args = line.split
      args = args.empty? ? nil : args * ' '
      if args and has_subcommands?(cmd)
        if cmd = find_subcommand_in_args(subcommands(cmd), line.split)
          # XXX Completion proc should be passed array of subcommands somewhere
          args = line.split.join('_').match(/^#{cmd}/).post_match.gsub('_', ' ').strip
          args = nil if args.empty?
        end
      end
      [cmd, args]
    end

    # Extracts a subcommand if there is one from the command line submitted. I guess this is a hack. 
    def find_subcommand_in_args(subcommands, args)
      (subcommands & (1..args.size).to_a.map {|num_elems| args.first(num_elems).join('_')}).max
    end

    # Looks up command shortcuts (e.g. '?' is a shortcut for 'help'). Short
    # cuts can be added by using the shortcut class method.
    def translate_shortcut(cmd)
      command_lookup_table[cmd] || cmd
    end

    # Indicates if the passed in command has any registerd shortcuts.
    def has_shortcuts?(cmd)
      command_shortcuts(cmd)
    end

    # Returns the set of registered shortcuts for a command, or nil if none.
    def command_shortcuts(cmd)
      shortcuts[cmd]  
    end

    # Called on command arguments as they are passed into the command.
    def tokenize_args(args)
      args
    end

    # Cleans up the readline history buffer by performing tasks such as
    # removing empty lines and piggy-backed duplicates. Only executed if
    # running with readline support.
    def sanitize_readline_history(line)
      return unless readline_supported? 
      # Strip out empty lines
      Readline::HISTORY.pop if line.match(/^\s*$/)
      # Remove duplicates
      Readline::HISTORY.pop if Readline::HISTORY[-2] == line rescue IndexError
    end

    # Readline completion uses a procedure that takes the current readline
    # buffer and returns an array of possible matches against the current
    # buffer. This method sets the current procedure to use. Commands can
    # specify customized completion procs by defining a method following the
    # naming convetion complet_{command_name}.
    def set_completion_proc(cmd)
      return unless readline_supported?
      Readline.completion_proc = self.method(cmd)
    end

    # Called when the line entered at the prompt does not map to any of the
    # defined commands. By default it reports that there is no such command.
    def command_missing(command, args)
      write "No such command '#{command}'"
    end

    def default_prompt
      "#{self.class.name}> "
    end

end

module Enumerable #:nodoc:
  def longest_string_length
    inject(0) {|longest, item| longest >= item.size ? longest : item.size}
  end
end

if __FILE__ == $0
  Cmd.run
end
