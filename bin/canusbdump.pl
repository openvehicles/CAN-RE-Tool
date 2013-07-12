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

use Device::SerialPort;
use Time::HiRes qw( gettimeofday );

select STDOUT; $|=1;

my $device = glob '/dev/tty.usb*';
my $baud = '115200';
my $canusb;
my $canusb_p;
my $last_s;
my $last_us;
my $last_msm;

#$device = $1 if ($device =~ /\/dev\/(.+)$/);

$canusb = new Device::SerialPort ($device, 0);
$canusb->databits(8);
$canusb->baudrate($baud);
$canusb->parity("none");
$canusb->stopbits(1);
$canusb->handshake("none");
$canusb->stty_icrnl(1);

open $canusb_p, '+<', $device;

print $canusb_p "\r\r\rS8\rZ1\rV\rN\r";  # Initialise the CANUSB device
print $canusb_p "\rO\r";           # Open the CANUSB device

$SIG{INT}=\&quit;

my ($t_s,$t_us) = gettimeofday;
printf "%d.000 CXX CANUSBDUMP\n",$t_s;
printf "%d.000 CXX \n",$t_s;

while (<$canusb_p>)
  {
  chop;
  my $line = $_;
  &process($line);
  }

sub process
  {
  my ($line) = @_;

#  print "$line\n";

  # t1008A326490000001B0010DA
  if ($line =~ /^t(\d\d\d)(\d)(.+)/)
    {
    my ($id,$bytes,$msg) = ($1,$2,$3);
    my $data = substr $msg,0,$bytes*2;
    my @bytes;
    foreach ( $data =~ m/../g ) { push @bytes,uc(sprintf("%02.2x",hex($_))); }
    my $ms = hex(substr $msg,-4,4);

    if (!defined $last_s)
      {
      ($last_s,$last_us) = gettimeofday;
      $last_us = ($ms % 1000)*1000;
      }
    else
      {
      my $diff = ($ms > $last_msm)?($ms-$last_msm):(($ms+60000)-$last_msm);
      $last_us += $diff*1000;
      $last_s += ($last_us / 1000000);
      $last_us = ($last_us % 1000000);
      }
    $last_msm = $ms;


    # 70679164.000 R11 100 88 00 00 00 FF FF 1
    printf "%d.%03d R11 %03x %s\n",$last_s,$last_us/1000,hex($id),join(' ',@bytes);
    }

  }

sub quit
  {
  print $canusb_p "\rC\r";  # Close the CANUSB device
  close $canusb_p;
  kill 1, $$;
  exit(0);
  }
