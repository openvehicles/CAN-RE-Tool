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

package CRT::Messages;

my $pkg = __PACKAGE__;
use base (Exporter);

use Devel::Size qw(total_size);

my %listeners;

my @messages = ();
my $messages_size = 0;
my $messages_n = 0;

my %uniques = ();
my %uniques_n = ();
my %uniques_l = ();
my %uniques_decodes = ();
my %uniques_history = ();
my $uniques_size = 0;
my $uniques_hn = 0;

my %decodes = ();

sub clear_store
  {
  @messagestore = ();
  $messages_size = 0;
  $messages_n = 0;

  %uniques = ();
  %uniques_n = ();
  %uniques_l = ();
  $uniques_decodes = ();
  %uniques_history = ();
  $uniques_size = 0;
  $uniques_hn = 0;

  %decodes = ();
  }

sub store_stats
  {
  return ($messages_n,$messages_size,scalar keys %uniques,$uniques_hn,$uniques_size,scalar keys %decodes);
  }

sub store_ref
  {
  return \@messages;
  }

sub uniques_refs
  {
  return (\%uniques,\%uniques_n,\%uniques_l);
  }

sub uniques_history
  {
  my ($key) = @_;

  return @{$uniques_history{$key}};
  }

sub uniques_decodes_ref
  {
  my ($key) = @_;

  return \%{$uniques_decodes{$key}};
  }

sub decodes_ref
  {
  return \@decodes;
  }

sub register_listener
  {
  my ($id,$object) = @_;

  $listeners{$id} = $object;
  }

sub unregister_listener
  {
  my ($id) = @_;

  delete $listeners{$id};
  }

sub unregister_all_listeners
  {
  %listeners = ();
  }

sub feed_message
  {
  my ($msg) = @_;

  foreach (sort keys %listeners)
    {
    my $o = $listeners{$_};
    my $result = $o->incomingmessage($msg); 
    $msg = $result if (defined $result);  # Allow a listener to update the message
    }

  push @messages,$msg;
  $messages_n++;
  $messages_size += total_size($msg);
  }

sub update_unique
  {
  my ($key,$value) = @_;

  my ($last_s,$last_ms) = split ',',$value;
  $uniques{$key} = $value;
  $uniques_n{$key}++;
  $uniques_l{$key} = "$last_s,$last_ms";
  push @{$uniques_history{$key}},$value;
  $uniques_hn++;
  $uniques_size += total_size($value);
  }

sub update_decode
  {
  my ($key,$decode,$value) = @_;

  $uniques_decodes{$key}{$decode} = $value;
  $decodes{$decode} = $value;
  }

1;
