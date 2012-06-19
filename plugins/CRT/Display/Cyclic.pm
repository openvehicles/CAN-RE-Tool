#!/usr/bin/perl

package CRT::Display::Cyclic;

my $pkg = __PACKAGE__;
use base (Exporter);

use vars qw
  {
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
  return "Messages: Cyclic";
  }

sub select
  {
  my ($self,$cui,$window) = @_;

  $self->{'cui'} = $cui;
  $self->{'window'} = $window;

  $window->title('Messages: Cyclic');
  }

sub deselect
  {
  my ($self,$cui,$window) = @_;
  }

sub update
  {
  my ($self,$cui,$window) = @_;
  }

1;
