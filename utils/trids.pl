#!/usr/bin/perl

# 1371075602.498 R11 400 02 A2 07 80 FE 80 55 00

my @files = @ARGV;
my $baseline = shift @files;

print "Baseline: $baseline\n";
my %b_h = &trids($baseline);
print " Baseline IDs: ",scalar keys %b_h,"\n";

foreach (@files)
  {
  my $file = $_;
  my %h = &trids($file);
  print $file,":\n";
  &diffs(\%b_h,\%h);;
  }

exit(0);

sub trids
  {
  my ($file) = @_;

  my %ids = ();
  if (open F,'<',$file)
    {
    while (<F>)
      {
      chop;
      if (/^\d+\.\d+ R11 (\S+) (\S+)/)
        {
        my ($id,$b1) = ($1,$2);
        my $key = (($id eq '100')||($id eq '400')||($id eq '102'))?"$id:$b1":$id;
        $ids{$key}++;
        }
      }
    close F;
    }

  return %ids;
  }

sub diffs
  {
  my ($b,$h) = @_;

  my (%missing,%new);

  foreach (keys %{$b})
    {
    $missing{$_}++ if (!defined $h->{$_});
    }

  foreach (keys %{$h})
    {
    $new{$_}++ if (!defined $b->{$_});
    }

  if (scalar keys %missing > 0)
    {
    print "  Missing ",scalar keys %missing," ids (",join(', ',sort keys %missing),")\n";
    }
  if (scalar keys %new > 0)
    {
    print "  Found ",scalar keys %new," ids (",join(', ',sort keys %new),")\n";
    }
  }
