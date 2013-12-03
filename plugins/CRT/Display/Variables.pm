#!/usr/bin/perl

package CRT::Display::Variables;

my $pkg = __PACKAGE__;
use base (Exporter);

use CRT::Variables;

use vars qw
  {
  $cui
  $window
  $text
  $updated
  };

sub new
  {
  my $class = shift;
  $class = ref($class) || $class;
  my $self = {@_};
  bless( $self, $class );

  $self->{'updated'} = 0;

  return $self;
  }

sub name
  {
  return "Variables";
  }

sub select
  {
  my ($self,$cui,$window) = @_;

  $self->{'cui'} = $cui;
  $self->{'window'} = $window;

  $window->title('Variables');
  $self->{'text'} = $window->add("text", "TextViewer", -text => "");

  CRT::Variables::register_listenerall('CRT::Display::Variables',$self);
  }

sub deselect
  {
  my ($self,$cui,$window) = @_;

  $window->delete("text");
  undef $self->{'text'};

  CRT::Variables::unregiser_listenerall('CRT::Display::Variables');
  }

sub variableupdated
  {
  my ($self,$var,$val) = @_;

  $self->{'updated'}++;

  return undef;
  }

sub update
  {
  my ($self,$cui,$window) = @_;

  $self->{'updated'} = 0;

  my $v = CRT::Variables::variables_ref();

  my @msgs = ();

  foreach (sort keys %{$v})
    {
    my ($var,$val) = ($_,$v->{$_});

    push @msgs,sprintf("%-30.30s %s",$var,$val);
    }

  $self->{'text'}->text(join("\n",@msgs));
  $self->{'text'}->draw();
  Curses::curs_set(1);
  }

1;
