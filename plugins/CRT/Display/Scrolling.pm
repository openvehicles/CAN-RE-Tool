#!/usr/bin/perl

package CRT::Display::Scrolling;

my $pkg = __PACKAGE__;
use base (Exporter);

use CRT::Messages;

use vars qw
  {
  $cui
  $window
  $text
  @msgs
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
  return "Messages: Scrolling";
  }

sub select
  {
  my ($self,$cui,$window) = @_;

  $self->{'cui'} = $cui;
  $self->{'window'} = $window;

  $window->title('Messages: Scrolling');
  $self->{'text'} = $window->add("text", "TextViewer", -text => "");

  CRT::Messages::register_listener('CRT::Display::Scrolling',$self);
  }

sub deselect
  {
  my ($self,$cui,$window) = @_;

  $window->delete("text");
  undef $self->{'text'};

  CRT::Messages::unregister_listener('CRT::Display::Scrolling');
  }

sub incomingmessage
  {
  my ($self,$msg) = @_;

  my $height = $self->{'text'}->height();

  my ($dsec,$dms,$type,$key,$id,@bytes) = split ',',$msg;
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime $dsec;
  my $stamp = sprintf("%04d-%02d-%02d %02d:%02d:%02d.%03d",$year+1900,$mon+1,$mday,$hour,$min,$sec,$dms);

  my (@p_a,@p_h);
  foreach (0..7)
    {
    push @p_h,(defined $bytes[$_])?sprintf("%02.2x",$bytes[$_]):"  ";
    my $b = (defined $bytes[$_])?chr($bytes[$_]):chr(0);
    push @p_a, ($b =~ /[[:print:]]/)?$b:'.';
    }

  my @decodes = ();
  if ($key ne '')
    {
    my $d = CRT::Messages::uniques_decodes_ref($key);
    foreach (sort keys %{$d})
      { push @decodes,$_.':'.$d->{$_}; }
    }

  push @{$self->{'msgs'}},sprintf("%s %s %03.3x %s %s %s",$stamp,$type,$id,join(' ',@p_h),join('',@p_a),join(' ',@decodes));
  shift @{$self->{'msgs'}} while ((scalar @{$self->{'msgs'}})>$height);

  my $newtext = join("\n",reverse @{$self->{'msgs'}});
  $self->{'text'}->text($newtext);
  $self->{'text'}->draw();
  Curses::curs_set(1);

  return undef;
  }

sub update
  {
  # We work incrementally, so can just ignore this
  }

1;
