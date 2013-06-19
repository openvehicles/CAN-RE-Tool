#!/usr/bin/perl

package CRT::Display::Cyclic;

my $pkg = __PACKAGE__;
use base (Exporter);

use CRT::Messages;

use vars qw
  {
  $cui
  $window
  $text
  @msgs
  $pos
  };

sub new
  {
  my $class = shift;
  $class = ref($class) || $class;
  my $self = {@_};
  bless( $self, $class );

  $self->{'pos'} = 0;

  return $self;
  }

sub name
  {
  return "Messages: Cyclic";
  }

sub select
  {
  my ($self,$cui,$window) = @_;

  $self->{'cui'} = $cui;
  $self->{'window'} = $window;

  $window->title('Messages: Cyclic');
  $self->{'text'} = $window->add("text", "TextViewer", -text => "");

  CRT::Messages::register_listener('CRT::Display::Cyclic',$self);
  }

sub deselect
  {
  my ($self,$cui,$window) = @_;

  $window->delete("text");
  undef $self->{'text'};

  CRT::Messages::unregister_listener('CRT::Display::Cyclic');
  }

sub incomingmessage
  {
  my ($self,$msg) = @_;

  my $height = $self->{'text'}->height();

  my ($dsec,$dms,$type,$id,@bytes) = split ',',$msg;
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime $dsec;
  my $stamp = sprintf("%04d-%02d-%02d %02d:%02d:%02d.%03d",$year+1900,$mon+1,$mday,$hour,$min,$sec,$dms);

  my (@p_a,@p_h);
  foreach (0..7)
    {
    push @p_h,(defined $bytes[$_])?uc(sprintf("%02.2x",$bytes[$_])):"  ";
    my $b = (defined $bytes[$_])?chr($bytes[$_]):chr(0);
    push @p_a, ($b =~ /[[:print:]]/)?$b:'.';
    }

  my $pos = $self->{'pos'};
  $self->{'msgs'}[$pos] = sprintf("%s %s %03.3x %s %s",$stamp,$type,$id,join(' ',@p_h),join('',@p_a));
  $pos = ($pos+1) % $height;
  $self->{'pos'} = $pos;

  my $newtext = join("\n",@{$self->{'msgs'}});
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
