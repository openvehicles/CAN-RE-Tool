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

package CRT::Simulator::OBDII;

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

  return $self;
  }

sub name
  {
  return "OBDII Simulator";
  }

sub select
  {
  my ($self,$cui,$window) = @_;

  $self->{'cui'} = $cui;
  $self->{'window'} = $window;

  CRT::Messages::register_listener('aaa...OBDII_Simulator',$self);
  }

sub deselect
  {
  my ($self,$cui,$window) = @_;

  CRT::Messages::unregister_listener('aaa...OBDII_Simulator');
  }

sub incomingmessage
  {
  my ($self,$msg) = @_;

  my ($dsec,$dms,$type,$id,@bytes) = split ',',$msg;

  return $msg;
  }

1;
