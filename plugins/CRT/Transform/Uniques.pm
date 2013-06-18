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

package CRT::Transform::Uniques;

my $pkg = __PACKAGE__;
use base (Exporter);

use CRT::Command;

use vars qw
  {
  $cui
  $window
  %u
  };

sub new
  {
  my $class = shift;
  $class = ref($class) || $class;
  my $self = {@_};
  bless( $self, $class );

  CRT::Command::register_command('unique ',   sub { $self->command_callback_set(@_); } );
  CRT::Command::register_command('no unique ', sub { $self->command_callback_unset(@_); } );

  return $self;
  }

sub name
  {
  return "Unique Messages";
  }

sub select
  {
  my ($self,$cui,$window) = @_;

  $self->{'cui'} = $cui;
  $self->{'window'} = $window;

  CRT::Messages::register_listener('aaa...Uniques',$self);
  }

sub deselect
  {
  my ($self,$cui,$window) = @_;

  CRT::Messages::unregister_listener('aaa...Uniques');
  }

sub parseload_unique
  {
  my ($self,$keyname,$value) = @_;

  my ($id,$bytes) = ('','');
  foreach (split /\s+/,$value)
    {
    if (/^id=(.+)/i)
      {
      $id = $1;
      }
    elsif (/^bytes=(.+)/)
      {
      $bytes=$_;
      }
    }
  $self->{'u'}{$id}{$bytes} = $keyname;
  }

sub incomingmessage
  {
  my ($self,$msg) = @_;

  my ($dsec,$dms,$type,$id,@bytes) = split ',',$msg;

  my $idx = sprintf '%03x',$id;
  my $key = $idx;
  my $idh = $self->{'u'}{$idx};
  if (defined $idh)
    {
    my ($bh,@bl) = ('');
    foreach (@bytes)
      {
      my $b = sprintf '%02x',$_;
      $bh .= $b;
      push @bl,$bh;
      }
    $key = $idx;
    foreach (split /,/,$idh)
      {
      $key .= ':'.$bl[$_ - 1];
      }
    }

  $msg = join ',',$dsec,$dms,$type,$id,@bytes;

  CRT::Messages::update_unique($key,$msg);
  return $msg;
  }

sub command_callback_set
  {
  my ($self,$cui,$window,$command,@args) = @_;

  $self->{'u'}{$args[0]} = $args[1];

  $window->text("Define unique key for ID " . $args[0] . " on byte(s) " . $args[1]);
  $window->draw();
  }

sub command_callback_unset
  {
  my ($self,$cui,$window,$command,@args) = @_;

  delete $self->{'u'}{$args[u]};

  $window->text("Clear unique key for ID " . $args[0]);
  $window->draw();
  }

1;
