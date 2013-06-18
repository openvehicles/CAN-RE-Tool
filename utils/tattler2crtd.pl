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

# tattler2crtd
#
# A utility to convert Tattler log format to CRTD for CAN-RE-Tool

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

  printf "%d.%03d CXX Tattler tattler2crtd converted log\n",0,0;
  if (defined $filename)
    {
    if ($filename =~ /([^\/]+)$/)
      {
      printf "%d.%03d CXX Tattler log: %s\n",0,0,$1;
      }
    }

  PROCESS: while(<$fh>)
    {
    chop;
    #10:40:58.834566 S. id=0x000004d1 dat=0x00:0x00:0x00:0x01:0x1a:0x77:0x00:0x9c
    if (/^(\d\d)\:(\d\d)\:(\d\d)\.(\d+)\s+S\.\s+id=0x00000(...)\s+dat=(.+)/)
      {
      my ($h,$m,$s,$us,$id,$rest) = ($1,$2,$3,$4,uc($5),$6);
      my @d; foreach (split /\:/,$rest) { push @d,uc($1) if (/0x(..)/); }
      printf "%d.%03d R11 %s %s\n",($h*3600)+($m*60)+$s,$us/1000,$id,join(' ',@d);
      }
    }

  close $fh;
  }
