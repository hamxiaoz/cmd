require_relative '../lib/cmd'
require 'test/unit'
require 'stringio'

class TCmdException < StandardError
end

class CustomException < StandardError
end

class AnotherCustomException < StandardError
end

class Cmd
  def in
    @stdin
  end

  def out
    @stdout
  end
end

class TCmdBasic < Cmd
end

class TCmdWithCommands < Cmd

  prompt_with ENV['USER'] 

  handle CustomException, :handle_custom_exception
  handle AnotherCustomException, 'Handled another custom exception'
  handle ZeroDivisionError, 'Division by zero'

  def do_exit_violently
    raise TCmdException
  end

  def do_trigger_custom_exception
    raise CustomException
  end

  def do_trigger_another_custom_exception
    raise AnotherCustomException
  end
  
  def do_trigger_zero_division_error
    1 / 0
  end

  def do_simple
    write 'Ran simple command'
  end

  def do_shell_type
  end

  protected

    def handle_custom_exception
      write 'Handled custom exception'
    end

    def handle_exception(exception)
      write 'Exception was raised'
    end

    def empty_line
      write 'Empty line was entered'
    end

end

class TCmdLifecycle < Cmd

  def methods_ran
    (@methods_ran ||= []).sort!
    @methods_ran
  end

  protected

    def setup;    methods_ran << 'setup'    end
    def preloop;  methods_ran << 'preloop'  end
    def postloop; methods_ran << 'postloop' end

    def precmd(line)
      methods_ran << 'precmd'
      line
    end

    def postcmd(line)
      methods_ran << 'postcmd'
      line
    end

end

class TC_Cmd < Test::Unit::TestCase
  def setup
    @basic     = setup_mock_cmd(TCmdBasic)
    @cmd       = setup_mock_cmd(TCmdWithCommands)
    @lifecycle = setup_mock_cmd(TCmdLifecycle)
  end

  def test_simple_command
    run_command 'simple'
    assert_stdout_equal "Ran simple command\n"
  end

  def test_custom_exception
    run_command 'trigger_custom_exception'
    assert_stdout_equal "Handled custom exception\n"
  end

  def test_another_custom_exception
    run_command 'trigger_another_custom_exception'
    assert_stdout_equal "Handled another custom exception\n"
  end
  
  def test_zero_division_error
    run_command 'trigger_zero_division_error'
    assert_stdout_equal "Division by zero\n"
  end

  def test_prompt
    assert_equal ENV['USER'], @cmd.send(:prompt)
  end

  def test_abbrev_command_lookup
    run_command 'si'
    assert_stdout_equal "Ran simple command\n"
  end

  def test_abbrev_command_ambiguous_lookup
    run_command 's'
    assert_stdout_equal "No such command 's'\n"
  end

  def test_empty_line
    run_command ' '
    assert_stdout_equal "Empty line was entered\n"
  end

  def test_lifecycle_callbacks
    run_command 'exit', @lifecycle
    assert_equal %w(postcmd postloop precmd preloop setup), 
                 @lifecycle.methods_ran
  end

  def test_command_list
    assert_equal %w(exit help shell), @basic.send(:command_list).sort
  end

  def test_subcommand_list
    assert_equal %w(exit_violently shell_type), @cmd.send(:subcommand_list).sort
  end

  def test_complete
    assert_equal %w(exit help shell), @basic.send(:complete, '').sort
    assert_equal %w(help), @basic.send(:complete, 'h')
    assert_equal [], @basic.send(:complete, 'asdf')
  end

  def test_has_subcommands?
    assert ! @cmd.send(:has_subcommands?, 'help')
    assert ! @basic.send(:has_subcommands?, 'help')
    assert @cmd.send(:has_subcommands?, 'exit')
    assert @cmd.send(:has_subcommands?, '!')
  end

  def test_subcommand_lookup
    assert_equal [], @basic.send(:subcommands, 'help')
    assert_equal %w(exit_violently), @cmd.send(:subcommands, 'exit')
    assert_equal %w(shell_type), @cmd.send(:subcommands, '!')
  end

  def test_documented_commands_list
    assert_equal %w(exit help shell), @basic.send(:documented_commands).sort
  end

  def test_handle_exception
    run_command 'exit violently'
    assert_stdout_equal "Exception was raised\n"
  end

  def test_undocummented_commands_list
    assert ! @basic.send(:undocumented_commands?)
    assert_equal [], @basic.send(:undocumented_commands)
  end

  def test_translate_shortcut
    assert_equal 'help', @basic.send(:translate_shortcut, 'help')
    assert_equal 'help', @basic.send(:translate_shortcut, '?')
  end

  def test_has_shortcuts?
    assert @cmd.send(:has_shortcuts?, 'help')
    assert !@cmd.send(:has_shortcuts?, 'exit')
  end

  def test_command_shortcuts
    assert_equal ['?'], @basic.send(:command_shortcuts, 'help')
  end

  def test_find_subcommand_in_args
    assert_equal 'help_me', @basic.send(:find_subcommand_in_args, 
                    %w(help_you help_me help_him), 
                    %w(help me help you))
    assert_equal 'help_me', @basic.send(:find_subcommand_in_args, 
                    %w(help_you help_me help_him), 
                    %w(help me))
    assert_equal nil, @basic.send(:find_subcommand_in_args, 
                    %w(help_you help_me help_him), 
                    %w(help her))
  end

  def test_command_missing
    run_command '??'
    assert_stdout_equal "No such command '??'\n"
  end

  def test_no_help
    run_command '? flarp'
    assert_stdout_equal "No help for command 'flarp'\n"
  end

  def test_current_command
    run_command 'help'
    assert_equal 'help', @cmd.send(:current_command)
  end

  def test_current_command_with_shortcut
    run_command '?'
    assert_equal 'help', @cmd.send(:current_command)
  end

  def test_help_on_single_command
    @basic.send(:execute_line, '? ?')
    actual = @basic.out.string
    @basic.out.rewind
    @basic.send(:print_help, 'help')
    expected = @basic.out.string
    assert_equal expected, actual

    @basic.send(:execute_line, 'help not-a-command')
    actual = @basic.out.string
    @basic.out.rewind
    @basic.send(:no_help, 'not-a-command')
    expected = @basic.out.string
    assert_equal expected, actual
  end

  def test_parse_line
    assert_equal ['help', nil], @basic.send(:parse_line, 'help')
    assert_equal ['help', nil], @basic.send(:parse_line, 'help ')
    assert_equal ['help', 'shell'], @basic.send(:parse_line, 'help shell')
    assert_equal ['shell_type', nil], @cmd.send(:parse_line, 'shell type')
    assert_equal ['shell_type', 'zsh'], @cmd.send(:parse_line, 'shell type zsh')
  end

  protected 

    def run_command(line, obj = @cmd)
      obj.in << line
      obj.in.rewind
      obj.run
      obj.out.pos = obj.send(:prompt).size
    end

    def assert_stdout_equal(line, obj = @cmd)
      assert_equal line, obj.out.read
    end

    def setup_mock_cmd(klass)
      obj = klass.new
      obj.stdin  = StringIO.new
      obj.stdout = StringIO.new
      obj.send :stoploop
      obj.turn_off_readline
      obj
    end
  
end
