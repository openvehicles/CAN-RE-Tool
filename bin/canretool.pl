#!/usr/bin/perl

#    Project:       CAN RE Tool
#    Date:          1 Apr 2012 (really)
#
#    Changes:
#    1.0  Initial release
#
#    (C) 2012  Mark Webb-Johnson
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

# canretool
#
# A Reverse Engineering tool for can bus messages, using the CAN USB device

BEGIN
  {
  push @INC,'./plugins';
  };

use EV;
use AnyEvent;
use AnyEvent::Handle;
use IO::Handle;
use Config::IniFiles;
#use Term::ReadKey;
#use Term::ANSIColor;
use Curses;
use Curses::UI;
use Device::SerialPort;
use Time::HiRes qw( gettimeofday );
use Module::Pluggable;
use Module::Pluggable::Object;
use Data::Dumper;
use CRT::Messages;
use CRT::Command;
use CRT::Decodes;

########################################################################
# Globals

my $sel_input;
my $sel_output;
my $sel_display;
my $sel_transform;
my %active_transforms;
my @rules_files;

########################################################################
# UI

my $cui = new Curses::UI( -color_support => 1,  -read_timeout => 0 );
$cui->{-read_timeout} = 0;

########################################################################
# Let's instantiate all the plugins...

my %plugins;

my $pluginfinder  = Module::Pluggable::Object->new(require=>1, search_path => ['CRT::Helper','CRT::Input','CRT::Output','CRT::Display','CRT::Transform']);
my @pluginlist = sort $pluginfinder->plugins();
$cui->progress(
        -max => scalar @pluginlist,
        -message => "Loading plugins...",
        -bfg => 'yellow',
    );

my $plugincount = 0;
foreach my $plugin (@pluginlist)
  {
  $cui->setprogress($plugincount++,"Loading $plugin..."); select undef,undef,undef,0.05;
  $plugins{$plugin} = $plugin->new();
  }
$cui->setprogress(scalar @pluginlist,'Plugins loaded ok');
$cui->noprogress;

my (@inputs,@outputs,@displays,@transforms);
my ($input_idx, $output_idx, $display_idx, $transform_idx) = (0,0,0,0);
foreach (sort keys %plugins)
  {
  my $plugin = $_;
  my $name = $plugins{$plugin}->name();
  if ($plugin =~ /^CRT::Input::(.+)/)
    {
    my $idx = $input_idx++;
    my $selected = ($plugin =~ /XNone$/)?'o':' ';
    push @inputs,{ -label => "<$selected> ".$name, -value => sub { &select_input($plugin,$idx); }, -crtplugin => $plugin };
    }
  elsif ($plugin =~ /^CRT::Output::(.+)/)
    {
    my $idx = $output_idx++;
    my $selected = ($plugin =~ /XNone$/)?'o':' ';
    push @outputs,{ -label => "<$selected> ".$name, -value => sub { &select_output($plugin,$idx); }, -crtplugin => $plugin };
    }
  elsif ($plugin =~ /^CRT::Display::(.+)/)
    {
    my $idx = $display_idx++;
    my $selected = ($plugin =~ /XNone$/)?'o':' ';
    push @displays,{ -label => "<$selected> ".$name, -value => sub { &select_display($plugin,$idx); }, -crtplugin => $plugin };
    }
  elsif ($plugin =~ /^CRT::Transform::(.+)/)
    {
    my $idx = $transform_idx++;
    push @transforms,{ -label => "[ ] ".$name, -value => sub { &select_transform($plugin,$idx); }, -crtplugin => $plugin };
    }
  }

########################################################################
# Menus and Windows...

my @menu =
  (
    { -label => 'File', -submenu => [ { -label => 'Exit         ^Q', -value => \&ui_exitdialog  } ] },
    { -label => 'Display', -submenu => \@displays },
    { -label => 'Inputs', -submenu => \@inputs },
    { -label => 'Outputs', -submenu => \@outputs },
    { -label => 'Transforms', -submenu => \@transforms }
  );
 
my $menu = $cui->add(
        'menu','Menubar', 
        -menu => \@menu,
        -fg  => "yellow",
        -bg  => "blue",
);

# The top status bar
my $win_statusbar = $cui->add('winstatusbar','Window',
                           -border => 0,
                           -y => -1,
                           -x => 1,
                           -height => 1,
                           -width => -1,
                           -bg => 'blue',
                           -fg => 'yellow',
                          );

# The main display area, used by DISPLAY panels
my $win_display = $cui->add(
                     'windisplay', 'Window',
                     -border => 1,
                     -y    => 1,
                     -x    => 0,
                     -padbottom => 13,
                     -tfg       => 'blue',
                     -tbg       => 'yellow',
                     -bfg  => 'yellow',
                     );

# The STORE area goes on the bottom left
my $win_store = $cui->add('winstore','Window',
                          -border => 1,
                          -y => -1,
                          -x => 0,
                          -width => 30,
                          -height => 13,
                          -title => 'Message Store',
                          -padbottom => 1,
                          -tfg       => 'blue',
                          -tbg       => 'yellow',
                          -bfg => 'yellow',
                          );
my $win_store_text = $win_store->add("text", "TextViewer",
                           -text => "",
                           -height => 10,
                           -showoverflow => 0
                          );

# The COMMAND area goes in the centre bottom
my $win_command = $cui->add('wincommand','Window',
                          -border => 1,
                          -y => -1,
                          -x => 30,
                          -width => -1,
                          -height => 13,
                          -padbottom => 1,
                          -padright => 30,
                          -title => 'Command and Control',
                          -tfg       => 'blue',
                          -tbg       => 'yellow',
                          -bfg => 'yellow'
                          );
my $win_command_req = $win_command->add("req", "TextEditor",
                           -text => "",
                           -singleline => 1,
                           -height => 3,
                           -border => 1
                          );
my $win_command_rep = $win_command->add("rep", "TextViewer",
                           -text => "",
                           -height => -1,
                           -y => 3,
                           -vscrollbar => 1,
                           -wrapping => 1
                          );
$win_command_req->set_binding( \&ui_commandissue, KEY_ENTER);
$win_command_req->set_binding( \&ui_commandcomplete, "\cI");

# The INPUT area goes in the bottom right
my $win_input = $cui->add('wininput','Window',
                          -border => 1,
                          -y => -7,
                          -x => -1,
                          -width => 30,
                          -height => 7,
                          -padbottom => 1,
                          -title => 'Input',
                          -tfg       => 'blue',
                          -tbg       => 'yellow',
                          -bfg => 'yellow'
                          );
my $win_input_text = $win_input->add("text", "TextViewer",
                           -text => "",
                           -height => 3,
                           -showoverflow => 0
                          );
my $win_input_progress = $win_input->add("progress", "Progressbar",
                           -max => 100,
                           -pos => 0,
                           -height => 1,
                           -y => 3,
                           -border => 0
                          );

# The OUTPUT area goes in the bottom right, below INPUT
my $win_output = $cui->add('winoutput','Window',
                          -border => 1,
                          -y => -1,
                          -x => -1,
                          -width => 30,
                          -height => 7,
                          -padbottom => 1,
                          -title => 'Output',
                          -tfg       => 'blue',
                          -tbg       => 'yellow',
                          -bfg => 'yellow',
                          );
my $win_output_text = $win_output->add("text", "TextViewer",
                           -text => "",
                           -height => 3,
                           -showoverflow => 0
                          );
my $win_output_progress = $win_output->add("progress", "Progressbar",
                           -max => 100,
                           -pos => 0,
                           -height => 1,
                           -y => 3,
                           -border => 0
                          );

$cui->set_binding(sub { $menu->focus(); $menu->pulldown(); }, "\cX");
$cui->set_binding(sub { $menu->focus(); $menu->pulldown(); }, "\cF");
$cui->set_binding(sub { $menu->focus(); $menu->menu_right(); $menu->pulldown(); }, "\cP");
$cui->set_binding(sub { $menu->focus(); $menu->menu_right(); $menu->menu_right(); $menu->pulldown(); }, "\cN");
$cui->set_binding(sub { $menu->focus(); $menu->menu_right(); $menu->menu_right(); $menu->menu_right(); $menu->pulldown(); }, "\cO");
$cui->set_binding(sub { $menu->focus(); $menu->menu_right(); $menu->menu_right(); $menu->menu_right(); $menu->menu_right(); $menu->pulldown(); }, "\cT");
#$cui->set_binding(sub { $win_command_req->focus(); }, "\cI");
$cui->set_binding( \&ui_exitdialog , "\cQ");

CRT::Command::register_command('quit', \&ui_exitdialog);
CRT::Command::register_command('exit', \&ui_exitdialog);
CRT::Command::register_command('menu', sub { $menu->focus(); } );

my $io_stdin = AE::io 0, 0, \&ui_ticker;
my $tim_input = AE::timer 1.0, 1.0, \&ui_ticker_input;
my $tim_output = AE::timer 1.0, 1.0, \&ui_ticker_output;
my $tim_store = AE::timer 1.0, 1.0, \&ui_ticker_store;
my $tim_display = AE::timer 1.0, 1.0, \&ui_ticker_display;

# Default input...
$sel_input = $plugins{'CRT::Input::XNone'};
eval { $sel_input->select($cui,$win_display); };

# Default output...
$sel_output = $plugins{'CRT::Output::XNone'};
eval { $sel_output->select($cui,$win_display); };

# Default display...
$sel_display = $plugins{'CRT::Display::XNone'};
eval { $sel_display->select($cui,$win_display); };

# Setup default display...
eval { $sel_display->initdisplay($win_display); };


########################################################################
# Some callback commands

CRT::Command::register_command('display ',   \&command_setdisplay );
CRT::Command::register_command('input ',   \&command_setinput );
CRT::Command::register_command('output ',   \&command_setoutput );
CRT::Command::register_command('transform ',   \&command_settransform );

sub command_setdisplay
  {
  my ($cui,$window,$command,$d) = @_;

  my $idx = 0;
  IDX: foreach (sort keys %plugins)
    {
    my $plugin = $_;
    if ($plugin =~ /^CRT::Display::(.+)/)
      {
      if ($1 eq $d)
        {
        &select_display($plugin,$idx);
        last IDX;
        }
      $idx++;
      }
    }
  }

sub command_setinput
  {
  my ($cui,$window,$command,$d) = @_;

  my $idx = 0;
  IDX: foreach (sort keys %plugins)
    {
    my $plugin = $_;
    if ($plugin =~ /^CRT::Input::(.+)/)
      {
      if ($1 eq $d)
        {
        &select_input($plugin,$idx);
        last IDX;
        }
      $idx++;
      }
    }
  }

sub command_setoutput
  {
  my ($cui,$window,$command,$d) = @_;

  my $idx = 0;
  IDX: foreach (sort keys %plugins)
    {
    my $plugin = $_;
    if ($plugin =~ /^CRT::Output::(.+)/)
      {
      if ($1 eq $d)
        {
        &select_output($plugin,$idx);
        last IDX;
        }
      $idx++;
      }
    }
  }

sub command_settransform
  {
  my ($cui,$window,$command,$d) = @_;

  my $idx = 0;
  IDX: foreach (sort keys %plugins)
    {
    my $plugin = $_;
    if ($plugin =~ /^CRT::Transform::(.+)/)
      {
      if ($1 eq $d)
        {
        &select_transform($plugin,$idx);
        last IDX;
        }
      $idx++;
      }
    }
  }

########################################################################
# Load all rules specified...

@rules_files = @ARGV;

my @rules_files_loaded = ();
foreach (@rules_files)
  {
  my $rf = $_;
  if (open RF,'<',$rf)
    {
    push @rules_files_loaded,$rf;
    RFL: while (<RF>)
      {
      chop;
      next RFL if (/^\s*#/);
      next RFL if (/^\s*$/);
      my $command = $_;
      CRT::Command::command_issue($command,$cui,$win_command_rep);
      }
    close RF;
    }
  }

if (scalar @rules_files_loaded > 0)
  {
  $win_command_rep->text("Loaded: " . join(', ',@rules_files_loaded));
  $win_command_rep->draw();
  }

########################################################################
# Main loop

# And focus on the command entry area...
$win_command_req->focus();

# Main event loop...
EV::loop();

########################################################################
# ui_ticker
#
# The main display update ticker

sub ui_ticker
  {
  $cui->do_one_event();
  Curses::curs_set(1);
  }

########################################################################
# ui_bytes
#
# A nice format for bytes

sub ui_bytes
  {
  my ($size, $n) = (shift, 0);

  ++$n and $size /= 1024 until $size < 1024;
  return sprintf "%.1f %s", 
          $size, ( qw[ bytes KB MB GB ] )[ $n ];
  }

########################################################################
# ui_comma
#
# A nice format for integers with commas

sub ui_comma
  {
  (my $num = shift) =~ s/\G(\d{1,3})(?=(?:\d\d\d)+(?:\.|$))/$1,/g;
  return $num;
  }

########################################################################
# ui_shutdown
#
# UI for handling shutdown of the system

sub ui_shutdown
  {
  # Deselect current objects
  eval { $sel_display->deselect($cui,$win_display); } if (defined $sel_display);
  eval { $sel_input->deselect($cui,$win_display); } if (defined $sel_input);
  eval { $sel_output->deselect($cui,$win_display); } if (defined $sel_output);
  foreach my $plugin (sort keys %active_transforms)
    { eval { $active_transforms{$plugin}->deselect($cui,$win_display); }; }

  # Shut down all the plugins
  foreach my $plugin (sort keys %plugins)
    {
    eval { $plugin->shutdown(); }
    }

  # Unregister all listeners
  CRT::Messages::unregister_all_listeners();

  # All done
  }

########################################################################
# ui_exitdialog
#
# UI for handling a dialog to confirm user wants to exit

sub ui_exitdialog()
  {
  my $return = $cui->dialog(
                     -message   => "Do you really want to quit?",
                     -title     => "Are you sure???",
                     -buttons   => ['yes', 'no'],
                     -border    => 1,
                     -bfg       => 'yellow',
                     -tfg       => 'blue',
                     -tbg       => 'yellow',
                     );

  if ($return)
    {
    &ui_shutdown();
    exit(0);
    }
  }

########################################################################
# ui_ticker_input
#
# Update the INPUT display window with current status

sub ui_ticker_input
  {
  my $newtext = '';
  if ((!defined $sel_input)||($sel_input == $plugins{'CRT::Input::XNone'}))
    {
    $newtext = "\n       No INPUT source";
    if ($win_input_progress->get() != 0)
      {
      $win_input_progress->pos(0);
      $win_input_progress->draw();
      Curses::curs_set(1);
      }
    }
  else
    {
    my ($file,$messages,$progress);
    eval { ($file,$messages,$progress) = $sel_input->progress(); };
    if (!defined $file)
      {
      $newtext = '';
      if ($win_input_progress->get() != 0)
        {
        $win_input_progress->pos(0);
        $win_input_progress->draw();
        Curses::curs_set(1);
        }
      }
    else
      {
      my @msgs;
      push @msgs,sprintf("%-20.20s%8.8s",$sel_input->name(),&ui_comma($messages));
      push @msgs,"";
      push @msgs,$file;
      $newtext = join "\n",@msgs;
      $progress = 0 if (!defined $progress);
      if ($win_input_progress->get() != $progress)
        {
        $win_input_progress->pos($progress);
        $win_input_progress->draw();
        Curses::curs_set(1);
        }
      }
    }
  if ($win_input_text->get() ne $newtext)
    {
    $win_input_text->text($newtext);
    $win_input_text->draw();
    Curses::curs_set(1);
    }
  }

########################################################################
# ui_ticker_output
#
# Update the OUTPUT display window with current status

sub ui_ticker_output
  {
  my $newtext = '';
  if ((!defined $sel_output)||($sel_output == $plugins{'CRT::Output::XNone'}))
    {
    $newtext = "\n       No OUTPUT source";
    }
  else
    {
    my ($file,$messages);
    eval { ($file,$messages) = $sel_output->progress(); };
    if (!defined $file)
      {
      $newtext = '';
      }
    else
      {
      my @msgs;
      push @msgs,$file;
      push @msgs,"";
      if (defined $messages)
        { push @msgs,"Messages: ".&ui_comma($messages); }
      else
        { push @msgs,""; }
      $newtext = join "\n",@msgs;
      }
    }
  if ($win_output_text->get() ne $newtext)
    {
    $win_output_text->text($newtext);
    $win_output_text->draw();
    Curses::curs_set(1);
    }
  }

########################################################################
# ui_ticker_store
#
# Update the STORE display window with current status

sub ui_ticker_store
  {
  my @msgs;

  my ($mn,$ms,$un,$uhn,$us,$dn) = CRT::Messages::store_stats();
  my ($nd,$ds) = CRT::Decodes::decoder_stats();

  push @msgs,sprintf("Messages:   %-16.16s",&ui_comma($mn));
  push @msgs,sprintf("  Size:     %-16.16s",&ui_bytes($ms));
  push @msgs,'';
  push @msgs,sprintf("Uniques:    %-16.16s",&ui_comma($un));
  push @msgs,sprintf("  History:  %-16.16s",&ui_comma($uhn));
  push @msgs,sprintf("  Size:     %-16.16s",&ui_bytes($us));
  push @msgs,sprintf("  Decodes:  %-16.16s",&ui_comma($dn));
  push @msgs,'';
  push @msgs,sprintf("Decoders:   %-16.16s",&ui_comma($nd));
  push @msgs,sprintf("  Size:     %-16.16s",&ui_bytes($ds));

  my $newtext = join "\n",@msgs;

  if ($win_store_text->get() ne $newtext)
    {
    $win_store_text->text($newtext);
    $win_store_text->draw();
    Curses::curs_set(1);
    }

  my @errors = CRT::Command::get_errors();
  if (scalar @errors > 0)
    {
    $win_command_rep->text("Error:\n  ".join("\n  ",@errors));
    $win_command_rep->draw();
    }
  }

########################################################################
# ui_ticker_display
#
# Update the current display window with current status

sub ui_ticker_display
  {
  eval { $sel_display->update($cui,$win_display); };
  }

########################################################################
# ui_commandissue
#
# The user has issued a UI command

sub ui_commandissue
  {
  my $command = $win_command_req->get();
  $win_command_req->text('');
  $win_command_req->focus();
  CRT::Command::command_issue($command,$cui,$win_command_rep);
  }

########################################################################
# ui_commandcomplete
#
# The user has requested completion of a UI command

sub ui_commandcomplete
  {
  my $commandpart = $win_command_req->get();
  $commandpart = CRT::Command::command_completion($commandpart, $cui, $win_command_rep);
  $win_command_req->text($commandpart);
  $win_command_req->cursor_to_end();
  $win_command_req->draw();
  $win_command_req->focus();
  }

########################################################################
# select_display
#
# Process menu selection for new DISPLAY

sub select_display
  {
  my ($plugin,$index) = @_;

  # Inform the current display it is being deselected
  if (defined $sel_display)
    {
    eval { $sel_display->deselect($cui,$win_display); };
    }

  # Turn on the selected, and off all the others...
  foreach my $idx (0..(scalar @displays)-1)
    {
    if ($idx == $index)
      { $displays[$idx]{'-label'} =~ s/\<.\>/\<o\>/; }
    else
      { $displays[$idx]{'-label'} =~ s/\<.\>/\< \>/; }
    }

  # Inform the new display that it is being selected
  $sel_display = $plugins{$displays[$index]{'-crtplugin'}};
  eval { $sel_display->select($cui,$win_display); };
  eval { $sel_display->update($cui,$win_display); };
  $win_display->draw();
  }

########################################################################
# select_input
#
# Process menu selection for new INPUT

sub select_input
  {
  my ($plugin,$index) = @_;

  # Inform the current input it is being deselected
  if (defined $sel_input)
    {
    eval { $sel_input->deselect($cui,$win_display); };
    }

  # Turn on the selected, and off all the others...
  foreach my $idx (0..(scalar @inputs)-1)
    {
    if ($idx == $index)
      { $inputs[$idx]{'-label'} =~ s/\<.\>/\<o\>/; }
    else
      { $inputs[$idx]{'-label'} =~ s/\<.\>/\< \>/; }
    }

  # Inform the new input that it is being selected
  $sel_input = $plugins{$inputs[$index]{'-crtplugin'}};
  eval { $sel_input->select($cui,$win_display); };
  }

########################################################################
# select_output
#
# Process menu selection for new OUTPUT

sub select_output
  {
  my ($plugin,$index) = @_;

  # Inform the current output it is being deselected
  if (defined $sel_output)
    {
    eval { $sel_output->deselect($cui,$win_display); };
    }

  # Turn on the selected, and off all the others...
  foreach my $idx (0..(scalar @outputs)-1)
    {
    if ($idx == $index)
      { $outputs[$idx]{'-label'} =~ s/\<.\>/\<o\>/; }
    else
      { $outputs[$idx]{'-label'} =~ s/\<.\>/\< \>/; }
    }

  # Inform the new output that it is being selected
  $sel_output = $plugins{$outputs[$index]{'-crtplugin'}};
  eval { $sel_output->select($cui,$win_display); };
  }

########################################################################
# select_transform
#
# Process menu selection for new TRANSFORM

sub select_transform
  {
  my ($plugin,$index) = @_;

  my $po = $plugins{$transforms[$index]{'-crtplugin'}};

  if ($transforms[$index]{'-label'} =~ /^\[X\] /)
    {
    # Disable the transform plugin...
    $transforms[$index]{'-label'} =~ s/\[.\] /\[ \] /;
    if ($sel_transform == $po)
      {
      # Currently active transform is the selected one, so deselect it
      undef $sel_transform;
      }
    eval { $po->deselect($cui,$window); };
    delete $active_transforms{$plugin};
    }
  else
    {
    # Enable the transform plugin...
    $transforms[$index]{'-label'} =~ s/\[.\] /\[X\] /;
    $active_transforms{$plugin} = $po;
    eval { $po->select($cui,$window); };
    }

  # Nasty hack to re-display the menu as best we can
  #$cui->schedule_event(
  #  sub
  #    {
  #    $menu->focus();
  #    $menu->menu_right();
  #    $menu->menu_right();
  #    $menu->menu_right();
  #    $menu->menu_right();
  #    $menu->pulldown();
  #    }
  #  );
  }

