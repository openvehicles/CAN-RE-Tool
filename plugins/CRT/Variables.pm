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

package CRT::Variables;

my $pkg = __PACKAGE__;
use base (Exporter);

use CRT::Decodes;
use CRT::Command;
use Devel::Size qw(total_size);

my %listeners;
my %listenersall;
my %variables;

INIT
  {
  &init_variables();
  }

sub init_variables
  {
  CRT::Command::register_command('var ',   \&command_callback_var );
  CRT::Command::register_command('no var ', \&command_callback_novar );
  CRT::Command::register_command('clear variables', \&command_callback_clearvariables );
  CRT::Command::register_completions('var ', \&command_callback_completions );
  CRT::Command::register_completions('no var ', \&command_callback_completions );
  }

sub command_callback_var
  {
  my ($cui,$window,$command,@args) = @_;

  my $var = shift @args;
  my $val = join(" ",@args);

  &update_variable($var,$val);

  $window->text("Defined variable $var = $val");
  $window->draw();
  }

sub command_callback_novar
  {
  my ($cui,$window,$command,@args) = @_;

  my $cmd2 = shift @args;
  my $var = shift @args;

  &update_variable($var,undef);

  $window->text("Cleared variable $var");
  $window->draw();
  }

sub command_callback_clearvariables
  {
  my ($cui,$window,$command,@args) = @_;

  &clear_decoders();

  $window->text("Cleared all decoders");
  $window->draw();
  }

sub command_callback_completions
  {
  my ($commandpart) = @_;

  my $prefix = ($commandpart =~ /^no /)?'no var ':'var ';
  my @c;

  foreach (sort keys %variables)
    {
    my $cmd = $prefix . $_;
    push @c, $cmd if (substr($cmd,0,length($commandpart)) eq $commandpart);
    }

  return @c;
  }

sub clear_variables
  {
  %variables = ();
  }

sub variables_stats
  {
  }

sub variables_ref
  {
  return \%variables;
  }

sub get_variables
  {
  return sort keys %variables;
  }

sub get_variable
  {
  my ($var) = @_;

  return $variables{$var};
  }

sub register_listener
  {
  my ($var,$id,$object) = @_;

  $listeners{$var}{$id} = $object;
  }

sub unregister_listener
  {
  my ($id) = @_;

  foreach (keys %listeners)
    {
    my $var = $_;
    delete $listeners{$var}{$id} if (defined $listeners{$var}{$id});
    delete $listeners{$var} if (scalar keys %{$listeners{$var}} == 0);
    }

  %listeners = () if (scalar keys %listeners == 0);
  }

sub register_listenerall
  {
  my ($id,$object) = @_;

  $listenersall{$id} = $object;
  }

sub unregister_listenerall
  {
  my ($id) = @_;

  delete $listenersall{$id};
  }

sub unregister_all_listeners
  {
  %listeners = ();
  %listenersall = ();
  }

sub update_variable
  {
  my ($var,$val) = @_;

  if (defined $val)
    {
    $variables{$var} = $val;
    }
  else
    {
    delete $variables{$var};
    }

  if (defined $listeners{$var})
    {
    foreach (sort keys $listeners{$var})
      {
      my $id = $_;
      my $o = $listeners{$var}{$id};
      eval { $o->variableupdated($var,$val); };
      }
    }

  foreach (sort keys %listenersall)
    {
    my ($id,$o) = ($_,$listenersall{$id});
    eval { $o->variableupdated($var,$val); };
    }
  }

1;
