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
use CRT::Variables;
use Devel::Size qw(total_size);

# The decoders monitor particular unique keys. If updater, they run to produce the decoded value.
my %decoders = ();		# Key is <UniqueKey><DecoderKey>, value is code
my $ndecoders = 0;

# The coverage system is used to specify messages (or parts of messages) that have been decoded
my %coverage = ();		# Key is <UniqueKey>, value is comma-separated list of bytes covered (1-8)

INIT
  {
  &init_decoders();
  }

sub init_decoders
  {
  CRT::Command::register_command('decoder ',   \&command_callback_decoder );
  CRT::Command::register_command('no decoder ', \&command_callback_nodecoder );
  CRT::Command::register_command('clear decoders', \&command_callback_cleardecoders );
  CRT::Command::register_command('coverage ',   \&command_callback_coverage );
  CRT::Command::register_command('no decoder ', \&command_callback_nocoverage );
  CRT::Command::register_command('clear coverage', \&command_callback_clearcoverages );
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

sub command_callback_coverage
  {
  my ($cui,$window,$command,@args) = @_;

  my $key = shift @args;
  my $bytes = shift @args;

  &set_coverage($key,$bytes);

  $window->text("Defined coverage on $key for byte(s) $bytes");
  $window->draw();
  }

sub command_callback_nocoverage
  {
  my ($cui,$window,$command,@args) = @_;

  my $key = shift @args;

  &clear_coverage($key);

  $window->text("Cleared coverage on $key");
  $window->draw();
  }

sub command_callback_clearcoverages
  {
  my ($cui,$window,$command,@args) = @_;

  &clear_coverages();

  $window->text("Cleared all coverages");
  $window->draw();
  }

sub clear_coverages
  {
  %coverage = ();
  }

sub clear_coverage
  {
  my ($key) = @_;

  delete $coverage{$key};
  }

sub set_coverage
  {
  my ($key,$bytes) = @_;

  $coverage{$key} = $bytes;
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
      CRT::Variables::update_variable($decoder,join(' ',$v,$u));
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

sub get_coverage_bykey
  {
  my ($key) = @_;

  my @result = (0,0,0,0,0,0,0,0);

  if (defined $coverage{$key})
    {
    foreach (split /,/,$coverage{$key})
      { $result[$_-1]=1; }
    }

  return @result;
  }

sub decoder_stats
  {
  return ($ndecoders,total_size(\%decoders));
  }

1;
