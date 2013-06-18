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

package CRT::Command;

my $pkg = __PACKAGE__;
use base (Exporter);

my %completions;
my %commands;
my %commandstore;

sub store_command
  {
  my ($store,$command) = @_;

  $commandstore{$store}{$command} = 1;
  }

sub store_getcommands
  {
  my ($store) = @_;

  return sort keys %{$commandstore{$store}};
  }

sub store_getstores
  {
  return sort keys %commandstore;
  }

sub store_delete
  {
  my ($store,$command) = @_;

  delete $commandstore{$store}{$command};
  }

sub store_clear
  {
  my ($store) = @_;

  %{$commandstore{$store}} = ();
  }

sub store_clearall
  {
  %commandstore = ();
  }

sub register_command
  {
  my ($prefix,$callback) = @_;

  $commands{lc($prefix)} = $callback;
  }

sub register_completions
  {
  my ($prefix,$callback) = @_;

  $completions{lc($prefix)} = $callback;
  }

sub command_issue
  {
  my ($command, $cui, $window) = @_;

  my @candidates;
  my $found;

  foreach my $prefix (keys %commands)
    {
    if (lc(substr($command,0,length($prefix))) eq $prefix)
      {
      $found = $commands{$prefix};
      push @candidates,$prefix;
      }
    }
  if (scalar @candidates == 0)
    {
    # Try to auto-complete this for the user
    foreach my $prefix (keys %commands)
      {
      if (lc(substr($prefix,0,length($command))) eq $command)
        {
        $found = $commands{$prefix};
        push @candidates,$prefix;
        }
      }
    }

  if (scalar @candidates == 0)
    {
    $window->text("Command unrecognised:\n  $command");
    $window->draw();
    }
  elsif (scalar @candidates > 1)
    {
    # More than one matching command...
    $window->text("Ambiguous command - matching possibilities include:\n  ".join("\n  ",sort @candidates));
    $window->draw();
    }
  else
    {
    # Go ahead and run the command
    $window->text("");
    $window->draw();
    eval { &$found($cui, $window, split /\s+/,$command); };
    }
  }

sub command_completion
  {
  my ($commandpart, $cui, $window) = @_;

  my %candidates;

  foreach my $comp (keys %completions)
    {
    if (lc(substr($commandpart,0,length($comp))) eq $comp)
      {
      my $fn = $completions{$comp};
      foreach (&$fn($commandpart)) { $candidates{$_}=1; }
      }
    }

  foreach my $cmd (keys %commands)
    {
    if (lc(substr($cmd,0,length($commandpart))) eq $commandpart)
      { $candidates{$cmd}=1; }
    }

  if ((scalar keys %candidates)==1)
    {
    # A single command matches - just expand
    return (keys %candidates)[0];
    }
  elsif ((scalar keys %candidates)>1)
    {
    # Multiple expansions match - show them
    $window->text("Available commands:\n  ".join("\n  ",sort keys %candidates));
    $window->draw();
    }

  return $commandpart;
  }

1;
