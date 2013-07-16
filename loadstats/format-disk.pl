#!/usr/bin/perl -w
# for i in /var/log/sa/sa[0-9]*; do day=`echo $i | sed -e 's/[\/[:alpha:]]\+//g'` ; sar -d -h -f $i > /home/custuser/$HOSTNAME.disk.$day.csv; sar -h -r -f $i > /home/custuser/$HOSTNAME.mem.$day.csv; sar -h -u -f $i > /home/custuser/$HOSTNAME.cpu.$day.csv; done; zip ~custuser/$HOSTNAME-stats-1.zip /home/custuser/*.csv

use POSIX qw(strftime);

%serverdisk= ( 
        eul3300046 => { sda => 'local', sdb => 'general', sdc => 'package', sdd => 'cache', sde => 'cruise', sdf => 'teletext' },
        eul3300047 => { sda => 'local', sdb => 'general', sdc => 'package', sdd => 'cache', sde => 'cruise', sdf => 'teletext' },
        eul3300048 => { sda => 'local', sdb => 'sessions1', sdc => 'sessions2'  },
        eul3300049 => { sda => 'local', sdb => 'sessions1', sdc => 'sessions2' },
        eul3300050 => { sda => 'local', sdb => 'localmysql', sdc => 'general' },
        eul3300051 => { sda => 'local', sdb => 'localmysql', sdc => 'general' },
        eul3300052 => { sda => 'local', sdb => 'localmysql' }
);

my $statsfile = $ARGV[0] if $#ARGV >= 0;
my $partfile = $ARGV[1] if $#ARGV >= 1;

die "Please specify a sysstat csv file.\nUsage: $0 <sar disk stats.csv> <partitions>\n" unless $statsfile;
die "Please specify a /proc/partitions file.\nUsage: $0 <sar disk stats.csv> <partitions>\n" unless $partfile;

my %devpart;

# for i in `seq 1 7`; do ssh custuser@10.122.48.$i cat /proc/sys/kernel/hostname /proc/partitions > ${servers[$((i-1))]}.partitions; done

open(PARTFILE, "<$partfile") or die "unable to open partitions file $partfile: $!\n";

# first line contains the hostname
my $hostname=<PARTFILE>;
chomp $hostname;

# get minor/major to device name mapping
while(<PARTFILE>) {
        if(my ($maj,$min,$devname) = (/\s+(\d+)\s+(\d+)\s+\d+\s+([\w\d]+)/)) {
                $devpart{"$maj.$min"}=$devname;
        } 
}
close(PARTFILE);

# print the labels
print "time";
foreach $instance (sort keys(%{$serverdisk{$hostname}})) {
        print ",$serverdisk{$hostname}{$instance}-tps";
        print ",$serverdisk{$hostname}{$instance}-readsec/s";
        print ",$serverdisk{$hostname}{$instance}-writesec/s";
};
print "\n";

my %stats;
my $oldtimestamp;
open(STATSFILE, "<$statsfile") or die "unable to open sar file $partfile: $!\n";
while (<STATSFILE>) {
        if(my($host,$timestamp,$devmaj,$devmin,$metric,$value) = (/([\w\d-]+)\s+\d+\s+(\d+)\s+dev(\d+)-(\d+)\s+(tps|rd_sec\/s|wr_sec\/s)\s+([\d\.]+)/)) { 
                # first iteration?
                if(!$oldtimestamp) {
                        $oldtimestamp=$timestamp;
                }
                # should we start another row in the output?
                if($timestamp != $oldtimestamp) {
                        print strftime("%Y-%m-%d %H:%M", localtime($oldtimestamp));
                        foreach my $dev (sort keys %stats) {
                                print "," . join(',', @{$stats{$dev}});
                        }
                        print "\n";
                        $oldtimestamp=$timestamp;
                        %stats=();
                }
                # sanity check if the paritions file matches the sar file
                if($host ne $hostname) {
                        warn "Record doesn't match the hostname in partitions file";
                        last;
                }
                # metrics
                if(exists $devpart{"$devmaj.$devmin"} and exists $serverdisk{$hostname}{$devpart{"$devmaj.$devmin"}}) {
                        if($metric eq "tps") {
                                $stats{$devpart{"$devmaj.$devmin"}}[0]=$value;
                        } elsif($metric eq "rd_sec/s") {
                                $stats{$devpart{"$devmaj.$devmin"}}[1]=$value;
                        } elsif($metric eq "wr_sec/s") {
                                $stats{$devpart{"$devmaj.$devmin"}}[2]=$value;
                        } else {
                                warn "Unknown metric $metric";
                        }
                }
        } else {
                warn "Non-matching record: $_";
        }
}

#let's not forget the last record
print strftime("%Y-%m-%d %H:%M", localtime($oldtimestamp));
foreach my $dev (sort keys %stats) {
        print ',' . join(",", @{$stats{$dev}});
}
print "\n";
 
close(STATSFILE);
