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
use Getopt::Std;

$Getopt::Std::STANDARD_HELP_VERSION=1;

my %args;
my $mode;

sub usage {
  die <<"USAGE";
  @_
Usage: $0 [-d|-t] [input.sql]
 * A program to split plain-text MySQL dumps produced by mysqldump(8).
 * If no input file is specified - read from stdin.
 * By default splits into one file per database.
-t\t\tSplit each table into individual file
-d\t\tSplit the input into one file per database
USAGE
}

getopts('tdh',\%args);

usage if $args{h};

usage("Options -d and -t are mutually exclusive.") if (defined $args{t} and defined $args{d});

if(defined $args{t}) {
  $mode='table';
} else {
  # by default we split per-database
  $mode='database';
}

my $starttime=[gettimeofday];
my $database;
my $linecount=0;
my $count=0;
my $table;
my $outfile=sprintf("%05d", $count) . '-globals.sql';
open my $outfh, '>', "$outfile";

$OUTPUT_AUTOFLUSH=1;

while(<>) {
  if (m|\A-- Current Database: `(.+)`\Z|) {
    say "lines: $linecount, elapsed: " . tv_interval($starttime) . " sec";
    $database=$1;
    $linecount=0;
    $count++;
    print "Splitting database: $database, ";
    $outfile=sprintf("%05d", $count) . "-${database}";
    $starttime=[gettimeofday];
    # encountered a new database, time to switch the files
    close $outfh;
    if($mode eq 'database') {
      $outfile.='.sql';
    } elsif($mode eq 'table') {
      $outfile.='-create-and-use-db.sql';
      print "table: ";
    }
    open $outfh, '>', "$outfile";
  } elsif(m|\A-- Table structure for table `(.+)`\Z|) {
    $table=$1;
    if($mode eq 'table') {
      $count++;
      print "$table, ";
      close $outfh;
      $outfile=sprintf("%05d", $count) . "-${database}-${table}.sql";
      open $outfh, '>', $outfile;
    }
  };
  $linecount++;
  print $outfh $_;
}
say "lines: $linecount, elapsed: " . tv_interval($starttime) . " sec";
close $outfh;
