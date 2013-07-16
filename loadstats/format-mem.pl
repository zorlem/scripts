#!/usr/bin/perl

use POSIX qw(strftime);

# eul3300046      599     1247094601      -       kbmemfree       150528
# eul3300046      599     1247094601      -       kbmemused       32759068
# eul3300046      599     1247094601      -       %memused        99.54
# eul3300046      599     1247094601      -       kbbuffers       111996
# eul3300046      599     1247094601      -       kbcached        24232480
# eul3300046      599     1247094601      -       kbswpfree       2040020
# eul3300046      599     1247094601      -       kbswpused       224
# eul3300046      599     1247094601      -       %swpused        0.01
# eul3300046      599     1247094601      -       kbswpcad        0


print "time,kbmemfree,kbmemused,kbbuffers,kbcached,kbswpfree,kbswpused,kbswpcad\n";
while (<>) {
        if(/kbswpcad\s([\d\.]+)/) { 
                print ",$1\n"; 
        } elsif(/(kbmemused|kbbuffers|kbcached|kbswpfree|kbswpused)\s([\d\.]+)/) {
                print ",$2";
        } elsif(/[\w\d]+\s\d{1,3}\s(\d+)\s-\skbmemfree\s([\d\.]+)/) {
                print strftime("%Y-%m-%d %H:%M", localtime($1)) . ",$2";
        }
}
