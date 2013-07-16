#!/usr/bin/perl
# for i in /var/log/sa/sa[0-9]*; do day=`echo $i | sed -e 's/[\/[:alpha:]]\+//g'` ; sar -d -h -f $i > /home/custuser/$HOSTNAME.disk.$day.csv; sar -h -r -f $i > /home/custuser/$HOSTNAME.mem.$day.csv; sar -h -u -f $i > /home/custuser/$HOSTNAME.cpu.$day.csv; done; zip ~custuser/$HOSTNAME-stats-1.zip /home/custuser/*.csv
use POSIX qw(strftime);

print "time,user,nice,system,iowait,idle\n";
while (<>) {
        if(/%idle\s([\d\.]+)/) { 
                print ",$1\n"; 
        } elsif(/(nice|system|iowait)\s([\d\.]+)/) {
                print ",$2";
        } elsif(/[\w\d]+\s\d{1,3}\s(\d+)\sall\s%user\s([\d\.]+)/) {
                print strftime("%Y-%m-%d %H:%M", localtime($1)) . ",$2";
        }
}
