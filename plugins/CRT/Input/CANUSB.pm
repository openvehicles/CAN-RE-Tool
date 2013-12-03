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

package CRT::Input::CANUSB;

my $pkg = __PACKAGE__;
use base (Exporter);

use AnyEvent;
use Device::SerialPort;
use Time::HiRes qw( gettimeofday );
use CRT::Messages;

use vars qw
  {
  $device
  $baud
  $canusb
  $canusb_p
  $canusb_h
  $filepos
  $messages
  $last_s
  $last_us
  $last_msm
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
  return "CAN USB";
  }

sub select()
  {
  my ($self, $cui, $window) = @_;

  my $dialog = $cui->add(
        'canusb_source', 'Window',
        -width=>60,
        -height=>17,
        -border=>1,
        -ipad=>1,
        -fg=>-1,
        -bg=>-1,
        -title=>'CAN USB Selection',
        -titleinverse=>1,
        -centered=>1);

  my @usbsources = ();
  foreach (glob '/dev/tty.*')
    {
    push @usbsources,$1 if (/^\/dev\/tty\.(.+)$/);
    }

  my $sources = $dialog->add(
        'canusb_sources', 'Listbox',
        -border => 1,
        -title => 'USB Source',
        -titleinverse => 1,
        -y => 0,
        -x => 0,
        -width => 40,
        -height => 11,
        -wraparound => 1,
        -values => \@usbsources);

  my $baudrates = $dialog->add(
        'canusb_baudrates', 'Listbox',
        -border => 1,
        -title => 'Baud Rate',
        -titleinverse => 1,
        -y => 0,
        -x => 42,
        -width => 14,
        -height => 11,
        -radio => 1,
        -wraparound => 1,
        -values => [ 0, 1, 2, 3, 4, 5, 6, 7, 8 ],
        -labels => { 0=>'10Kbps', 1=>'20Kbps', 2=>'50Kbps', 3=>'100Kbps', 4=>'125Kbps', 5=>'250Kbps', 6=>'500Kbps', 7=>'800KBps', 8=>'1Mbps' });
  $baudrates->set_selection(8);

  my $buttons = $dialog->add(
        'canusb_buttons', 'Buttonbox',
        -y => -1,
        -x => 20,
        -buttons => [ 'ok', 'cancel' ]);

  $buttons->set_routine( 'press-button', sub {
        my $this = shift;
        my $parent = $this->parent;
        $cui->delete('canusb_source');
        $parent->loose_focus();
    } );

  $dialog->modalfocus();

  my $sel_baudrate = $baudrates->get();
  my $sel_source = $sources->get();
  my $sel_button = $buttons->get();

  return if ($sel_button == 0); # Cancelled

  $self->{'cui'} = $cui;
  $self->{'window'} = $window;

  # Baud rate mappings:
  # S0, S1, S2,  S3,  S4,  S5,  S6,  S7,    S8
  # 10, 20, 50, 100, 125, 250, 500, 800, 1Mbps

  $self->{'baud'} = '115200';
  my $device = '/dev/tty.' . $sel_source;
  return if (! -e $device);

  $self->{'device'} = $1 if ($device =~ /\/dev\/(.+)$/);

  my $canusb = new Device::SerialPort ($device, 0);
  return if (!defined $canusb);
  $self->{'canusb'} = $canusb;

  $canusb->databits(8);
  $canusb->baudrate($self->{'baud'});
  $canusb->parity("none");
  $canusb->stopbits(1);
  $canusb->handshake("none");
  $canusb->stty_icrnl(1);

  my $canusb_p;
  open $canusb_p, '+<', $device;
  my $canusb_h = new AnyEvent::Handle(fh => $canusb_p);
  $self->{'canusb_p'} = $canusb_p;
  $self->{'canusb_h'} = $canusb_h;
  $self->{'filepos'} = 0;
  $self->{'messages'} = 0;
  undef $self->{'last_s'};
  undef $self->{'last_us'};
  undef $self->{'last_msm'};
  $canusb_h->push_write("\r\r\rS".$sel_baudrate."\rZ1\r");  # Initialise the CANUSB device
  $canusb_h->push_write("\rO\r");           # Open the CANUSB device
  $canusb_h->push_read(line => sub { $self->_line(@_); } );

  CRT::Messages::register_transmitter('Input_CANUSB', $self );
  }

sub deselect()
  {
  my ($self, $cui, $window) = @_;

  my $canusb_h = $self->{'canusb_h'};

  my $cv = AE::cv;
  $canusb_h->push_write("\rC\r");           # Close the CANUSB device
  $canusb_h->on_drain(sub { $cv->send; });
  $cv->recv;

  undef $self->{'device'};
  undef $self->{'baud'};
  undef $self->{'canusb'};
  undef $self->{'canusb_p'};
  undef $self->{'canusb_h'};
  undef $self->{'filepos'};
  undef $self->{'messages'};
  undef $self->{'last_s'};
  undef $self->{'last_us'};
  undef $self->{'last_msm'};
  undef $self->{'cui'};
  undef $self->{'window'};

  CRT::Messages::unregister_transmitter('Input_CANUSB');
  }

sub progress
  {
  my ($self) = @_;

  return ($self->{'device'},
          $self->{'messages'});
  }

sub transmitmessage
  {
  my ($self, $msg) = @_;

  my ($dsec,$dms,$type,$id,@bytes) = split(/,/,$msg);

  if ($type eq 'T11')
    {
    my $t_id = sprintf '%03.3x',$id;
    my @t_b = ();
    foreach (@bytes) { push @t_b,sprintf('%02.2x',$_); }

    my $h = $self->{'canusb_h'};
    $h->push_write('t'.$t_id.(scalar @t_b).join('',@t_b)."\r");
    }
  }

sub _line
  {
  my ($self,$hdl,$line) = @_;

  $hdl->push_read(line => sub { $self->_line(@_); } );

  #t1008A326490000001B0010DA
  if ($line =~ /^t(\w\w\w)(\d)(.+)/)
    {
    $self->{'messages'}++;
    $self->{'filepos'} += length($line);
    my ($id,$bytes,$msg) = ($1,$2,$3);
    my $data = substr $msg,0,$bytes*2;
    my @bytes;
    foreach ( $data =~ m/../g ) { push @bytes,hex($_); }
    my $ms = hex(substr $msg,-4,4);

    if (!defined $self->{'last_s'})
      {
      ($self->{'last_s'},$self->{'last_us'}) = gettimeofday;
      $self->{'last_us'} = ($ms % 1000)*1000;
      }
    else
      {
      my $diff = ($ms > $self->{'last_msm'})?($ms-$self->{'last_msm'}):(($ms+60000)-$self->{'last_msm'});
      $self->{'last_us'} += $diff*1000;
      $self->{'last_s'} += ($self->{'last_us'} / 1000000);
      $self->{'last_us'} = ($self->{'last_us'} % 1000000);
      }
    $self->{'last_msm'} = $ms;

    CRT::Messages::feed_message(join(',',$self->{'last_s'},int($self->{'last-us'}/1000),'R11',hex($id),@bytes));
    }
  }

1;
