#!/usr/bin/perl
#
# A program to split MySQL's plain-text SQL dump files, as produced by
# mysqldump(8). Puts each database into a separate file.
#

use 5.012;
use warnings;
use strict;
use autodie;
use English qw( -no_match_vars);
use Time::HiRes qw(gettimeofday tv_interval);

$OUTPUT_AUTOFLUSH=1;

sub usage {
  die <<"USAGE";
    @_
Usage: $0 [-d] <input.sql>
 * A program to split plain-text MySQL dumps produced by mysqldump(8).
 * If no input file is specified - read from stdin.
USAGE
}

my $starttime=[gettimeofday];
my $database;
my $linecount=0;
my $dbcount=0;
my $outfile=sprintf("%.5d", $dbcount) . '-globals.sql';
open my $outfh, '>', "$outfile";

$OUTPUT_AUTOFLUSH=1;

while(<>) {
  if (m|\A-- Current Database: `(.+)`\Z|) {
    say "lines: $linecount, elapsed: " . tv_interval($starttime) . " sec";
    $database=$1;
    $linecount=0;
    $dbcount++;
    print "Splitting database: $database, ";
    $starttime=[gettimeofday];
    # encountered a new database, time to switch the files
    close $outfh;
    $outfile=sprintf("%.5d", $dbcount) . "-${database}.sql";
    open $outfh, '>', "$outfile.sql";
  }
  $linecount++;
  print $outfh $_;
}
say "lines: $linecount, elapsed: " . tv_interval($starttime) . " sec";
close $outfh;
