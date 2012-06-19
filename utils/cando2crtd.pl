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

# cando2crtd
#
# A utility to convert Tesla Roadster CANDO log format to CRTD for CAN-RE-Tool

foreach (@ARGV)
  {
  my $filename = $_;
  &convert($filename);
  }
exit(0);

sub convert
  {
  my ($filename) = @_;

  open $fh,'<',$filename;
  return if (!defined $fh);

  # First, look for a time message in the log, to try to synchronise things...
  my $cartime = 0;
  TIMESEARCH: while(<$fh>)
    {
    chop; chop;
    #RD11, 0.0015,400,01,01,00,00,00,00,4C,1D
    if (/^RD11\s*,\s*(\d+)\.(\d+)\s*,\s*(.+)/)
      {
      my ($sec,$ms10,$rest) = ($1,$2,$3);
      my ($id,@B) = split(/\s*,\s*/,$rest);
      if (($id eq '100')&&($B[0] eq '81'))
        {
        # Found a Tesla Roadster UTC date/time message...
        $cartime = hex($B[7].$B[6].$B[5].$B[4]) - $sec;
        last TIMESEARCH;
        }
      }
    }

  # Now, process the logs...
  seek $fh,0,0;

  printf "%d.%03d CXX OVMS Tesla Roadster cando2crtd converted log\n",$cartime,0;
  if (defined $filename)
    {
    if ($filename =~ /([^\/]+)$/)
      {
      printf "%d.%03d CXX OVMS Tesla roadster log: %s\n",$cartime,0,$1;
      }
    }

  PROCESS: while(<$fh>)
    {
    chop; chop;
    #RD11, 0.0015,400,01,01,00,00,00,00,4C,1D
    if (/^(\S)D11\s*,\s*(\d+)\.(\d+)\s*,\s*(.+)/)
      { 
      my ($type,$sec,$ms,$rest) = ($1,$2,$3/10,$4);
      my ($id,@B) = split(/\s*,\s*/,$rest);
      printf "%d.%03d %s11 %03d %s\n",$cartime+$sec,$ms,$type,$id,join(' ',@B);
      }
    }

  close $fh;
  }
