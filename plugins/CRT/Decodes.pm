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

package CRT::Decodes;

my $pkg = __PACKAGE__;
use base (Exporter);

use CRT::Command;
use CRT::Messages;
use Devel::Size qw(total_size);

my %decoders = ();
my $ndecoders = 0;

INIT
  {
  &init_decoders();
  }

sub init_decoders
  {
  CRT::Command::register_command('decoder ',   \&command_callback_decoder );
  CRT::Command::register_command('no decoder ', \&command_callback_nodecoder );
  CRT::Command::register_command('clear decoders', \&command_callback_cleardecoders );
  }

sub command_callback_decoder
  {
  my ($cui,$window,$command,@args) = @_;

  my $key = shift @args;
  my $decoder = shift @args;
  my $code = join(" ",@args);

  &set_decoder($key,$decoder,$code);

  $window->text("Defined decoder $decoder on $key with $code");
  $window->draw();
  }

sub command_callback_nodecoder
  {
  my ($cui,$window,$command,@args) = @_;

  my $key = shift @args;
  my $decoder = shift @args;

  &clear_decoder($key,$decoder);

  $window->text("Cleared decoder $decoder on $key");
  $window->draw();
  }

sub command_callback_cleardecoders
  {
  my ($cui,$window,$command,@args) = @_;

  &clear_decoders();

  $window->text("Cleared all decoders");
  $window->draw();
  }

sub clear_decoders
  {
  %decoders = ();
  $ndecoders = 0;
  CRT::Messages::clear_decodes();
  }

sub clear_decoder
  {
  my ($key,$decoder) = @_;

  if (defined $decoders{$key}{$decoder})
    {
    delete $decoders{$key}{$decoder};
    $ndecoders--;
    }
  CRT::Messages::clear_decode($decoder);
  }

sub set_decoder
  {
  my ($key,$decoder,$code) = @_;

  $ndecoders++ if (!defined $decoders{$key}{$decoder});
  $decoders{$key}{$decoder} = $code;
  CRT::Messages::clear_decode($decoder);
  }

sub update_decode
  {
  my ($key,$value) = @_;

  return if (!defined $decoders{$key});

  my ($dsec,$dms,$type,$id,@b) = split /,/,$value;
  foreach (sort keys %{$decoders{$key}})
    {
    my $decoder = $_;
    my $code = $decoders{$key}{$decoder};
    my ($d1,$d2,$d3,$d4,$d5,$d6,$d7,$d8) = @b;
    my ($v,$u) = eval $code;
    if (!defined $v)
      {
      my $es = join(' ',$@);
      $es =~ s/\n//g;
      CRT::Command::set_error("Decoder error: key $key decoder $decoder code $code error $es");
      }

    if ((defined $v)&&(defined $u))
      {
      CRT::Messages::update_decode($decoder,$v,$u);
      }
    }
  }

sub get_decoders_bykey
  {
  my ($key) = @_;

  if (defined $decoders{$key})
    { return keys %{$decoders{$key}}; }
  else
    { return (); }
  }

sub decoder_stats
  {
  return ($ndecoders,total_size(\%decoders));
  }

1;
