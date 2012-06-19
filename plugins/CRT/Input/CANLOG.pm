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

package CRT::Input::CANLOG;

my $pkg = __PACKAGE__;
use base (Exporter);

use AnyEvent;
use CRT::Messages;

use vars qw
  {
  $filepath
  $filename
  $filehandle
  $filepos
  $filesize
  $messages
  $progress
  $lastline
  $timer
  $cui
  $window
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
  return "CRTD log file";
  }

sub select()
  {
  my ($self, $cui, $window) = @_;

  my $file = $cui->loadfilebrowser(
             -title => "Choose CAN LOG file to load",
             -mask  => [
                        ['\.crtd$', 'CRTD files (*.txt)' ],
                        ['.',       'All files (*)'      ]
                       ],
              );
  if (defined $file)
    {
    my $fh;
    open $fh, '<', $file;
    $self->{'filehandle'} = $fh;
    $self->{'filepath'} = $file;
    $self->{'filename'} = $2 if ($file =~ /(\/?)([^\/]+)$/);
    $self->{'filepos'} = 0;
    $self->{'filesize'} = -s $fh;
    $self->{'progress'} = 0;
    $self->{'messages'} = 0;
    my $line = <$fh>; chop $line; $self->{'lastline'} = $line;
    $self->{'timer'} = AE::timer 0, 0, sub { $self->_tickercallback(); };
    }

  $self->{'cui'} = $cui;
  $self->{'window'} = $window;
  }

sub deselect()
  {
  my ($self, $cui, $window) = @_;

  undef $self->{'filehandle'};
  undef $self->{'filepath'};
  undef $self->{'filename'};
  undef $self->{'filepos'};
  undef $self->{'filesize'};
  undef $self->{'progress'};
  undef $self->{'messages'};
  undef $self->{'lastline'};
  undef $self->{'timer'};
  undef $self->{'cui'};
  undef $self->{'window'};
  }

sub progress
  {
  my ($self) = @_;

  return ($self->{'filename'},
          $self->{'messages'},
          $self->{'progress'});
  }

sub _tickercallback
  {
  my ($self) = @_;

  my ($tim_last,$tim_last_r)=($1,$2) if ($self->{'lastline'} =~ /^(\d+\.\d+)\s(.+)/);
  if (defined $tim_last)
    {
    my ($last_s,$last_ms) = split /\./,$tim_last;
    if ($tim_last_r =~ /(R11) (\S+) (.+)/)
      {
      my ($type,$id,$rest) = ($1,$2,$3);
      my @bytes;
      foreach (split /\s+/,$rest) { push @bytes,hex($_); }
      $self->{'messages'}++;

      CRT::Messages::feed_message(join(',',$last_s,$last_ms,'D11','',hex($id),@bytes));
      }
    }
  my $fh = $self->{'filehandle'};
  my $line = <$fh>;
  if (!defined $line)
    {
    $self->deselect($self->{'cui'},$self->{'window'});
    return;
    }
  $self->{'filepos'} += length($line);
  $self->{'progress'} = int((100.0*($self->{'filepos'}) / $self->{'filesize'})+0.5);
  chop $line;
  $self->{'lastline'} = $line;

  my $tim_next=$1 if ($line =~ /^(\d+\.\d+)\s/);

  my $wait = ((defined $tim_last)&&(defined $tim_next))?($tim_next-$tim_last):0;
  $self->{'timer'} = AE::timer $wait, 0, sub { $self->_tickercallback(); };
  }

1;
