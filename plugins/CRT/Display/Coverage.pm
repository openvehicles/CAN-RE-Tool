#!/usr/bin/perl

package CRT::Display::Coverage;

my $pkg = __PACKAGE__;
use base (Exporter);

use CRT::Messages;
use CRT::Decodes;

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
  return "Messages: Coverage";
  }

sub select
  {
  my ($self,$cui,$window) = @_;

  $self->{'cui'} = $cui;
  $self->{'window'} = $window;

  $window->title('Messages: Coverages');
  $self->{'text'} = $window->add("text", "TextViewer", -text => "");

  CRT::Messages::register_listener('CRT::Display::Coverage',$self);
  }

sub deselect
  {
  my ($self,$cui,$window) = @_;

  $window->delete("text");
  undef $self->{'text'};

  CRT::Messages::unregister_listener('CRT::Display::Coverage');
  }

sub incomingmessage
  {
  my ($self,$msg) = @_;

  $self->{'updated'}++;

  return undef;
  }

sub update
  {
  my ($self,$cui,$window) = @_;

  $self->{'updated'} = 0;

  my ($u) = CRT::Messages::uniques_refs();

  my @msgs = ();

  foreach (sort keys %{$u})
    {
    my ($uk,$uv) = ($_,$u->{$_});

    my ($dsec,$dms,$type,$id,@bytes) = split ',',$uv;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime $dsec;
    my $stamp = sprintf("%04d-%02d-%02d %02d:%02d:%02d.%03d",$year+1900,$mon+1,$mday,$hour,$min,$sec,$dms);

    my @covered = CRT::Decodes::get_coverage_bykey($uk);
    my (@p_a,@p_h);
    foreach (0..7)
      {
      if ($covered[$_])
        {
        push @p_h,(defined $bytes[$_])?'**':'  ';
        push @p_a,'*';
        }
      else
        {
        push @p_h,(defined $bytes[$_])?uc(sprintf("%02.2x",$bytes[$_])):"  ";
        my $b = (defined $bytes[$_])?chr($bytes[$_]):chr(0);
        push @p_a, ($b =~ /[[:print:]]/)?$b:'.';
        }
      }

    my ($un,$ua) = CRT::Messages::uniques_counts($uk);

    my @decoderkeys = CRT::Decodes::get_decoders_bykey($uk);
    my @decodes = ();
    foreach (sort @decoderkeys)
      {
      my $decoder = $_;
      my ($v,$u) = CRT::Messages::get_decodes($decoder);
      push @decodes,"$decoder=$v$u";
      }

    push @msgs,sprintf("%-30.30s [ %-5d %10dms ] %s %s %03.3x %s %s %s",$uk,$un,$ua,$stamp,$type,$id,join(' ',@p_h),join('',@p_a),join(', ',@decodes));
    }

  $self->{'text'}->text(join("\n",@msgs));
  $self->{'text'}->draw();
  Curses::curs_set(1);
  }

1;
