#!/usr/bin/perl

package CRT::Display::XNone;

my $pkg = __PACKAGE__;
use base (Exporter);

use vars qw {};

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
  return "None";
  }

sub select
  {
  my ($self,$cui,$window) = @_;

  $self->{'cui'} = $cui;
  $self->{'window'} = $window;

  $window->title('Please Choose a Display');
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
