#!/usr/bin/perl -w

# try to find iptables <-> filter discrepancies

my %filter;
open(FILTER, "tc filter ls dev eth2 |");

while(<FILTER>) {
	if(my ($fip) = (/^\s+match\s+([0-9a-f]+)\/f{8}/)) {
		$filter{$fip}=1;
	}
}

while(<>) {
	if(/^ACCEPT\s+all\s+--\s+([\d\.]+)\s+0.0.0.0\/0/) {
	my $boza=sprintf("%02x%02x%02x%02x", split(/\./, $1));
	if(!$filter{$boza}) { print "$1\n"; }
	} elsif(/^ACCEPT\s+all\s+--\s+0.0.0.0\/0\s+([\d\.]+)/) {
	my $boza=sprintf("%02x%02x%02x%02x", split(/\./, $1));
	if(!$filter{$boza}) { print "$1\n"; }
	} else { next;}	
}
