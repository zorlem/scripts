#!/usr/bin/perl -w
# $Id: deploy-config.pl 36 2012-06-11 18:38:09Z zorlem $

use warnings;
use strict;
use Carp;
use English qw( -no_match_vars );
use Getopt::Std;

$Getopt::Std::STANDARD_HELP_VERSION=1;

my $debug=1;
my %arguments;
my $parameterfile='config.ini';
my $template='./application.ini';
my $newconfig='./application.ini.new';
my %parameters;


sub usage {
    die <<"USAGE";
@_
Usage: $0 [-p parameter_file] <-e environment> <-o output file>
 * If no parameter file is specified, config.ini in the current directory is used by default.
 * The project directory should have a directory config in its parent.
 * Environment can be one of "staging" or "production".
USAGE
}

sub parseparams {
    my $pfile = shift;
    open my $PARFILE, '<', $pfile or croak "Unable to open parameters file '$pfile': $OS_ERROR";
    while(<$PARFILE>) {
        chomp;
        next if m/ ^\# | ^\s*$ /xms;
	# {%ENV:PROJECTNAME_SETTING%} = "value"
        if (my($param,$value) =
            ($_ =~ m{ ^{%
                ([\w]+:[\w\d_]+)
                %}[ ]=[ ]"
                (.*)
                "$ }xms)) {
            $debug and print "Found config parameter: $param:$value\n";
            $parameters{$param} = $value;
        }
    }
    close $PARFILE or croak "Failed to close file '$pfile': $OS_ERROR";
    return \%parameters;
}

sub genconfig {
    my $intemplate = shift;
    my $outconfig = shift;
    my $count = 0;
    open my $TEMPLATE, '<', $intemplate or croak "Unable to open the config file '$intemplate': $OS_ERROR";
    open my $CONF, '>', $outconfig or croak "Unable to open the _new_ config file '$outconfig': $OS_ERROR";
    while(<$TEMPLATE>) {
        # leave comments, empty lines and environment sections intact
        if(m/^\#|^\s*$|^\[[\w\d]+/xms) {
            print {$CONF} $_ or croak "Unable to save parameters to file '$outconfig': $OS_ERROR";
        }
        # check for tagged parameters
        elsif (my($zendoption,$param) = ($_ =~ m/^([\w\d\._-]+)\s*=\s*"{%([\w]+:[\w\d_]+)%}"/xms)) {
            if(exists $parameters{$param}) {
                print {$CONF} "$zendoption\t= " . q{"} . $parameters{$param} . q{"} . qq{\n}
                    or croak "Unable to save parameters to file '$outconfig': $OS_ERROR";
                $count++;
                print "replaced tag:$param for option:$zendoption with $parameters{$param}\n" if $debug;
            }
            else {
                print {$CONF} $_ or croak "Unable to save parameters to file '$outconfig': $OS_ERROR";
            }

        }
        # simply print everything else intact
        else {
            print {$CONF} $_ or croak "Unable to save parameters to file '$outconfig': $OS_ERROR";
        }
    }

    close $CONF or croak "Failed to close file '$outconfig': $OS_ERROR";
    close $TEMPLATE or croak "Failed to close file '$intemplate': $OS_ERROR";
    return $count;
}

getopts('p:e:o:u',\%arguments);

usage if $arguments{u};
usage('A required argument is missing.') unless(defined $arguments{e} and defined $arguments{o});

$parameterfile = $arguments{'p'} // $parameterfile;
my $environment = $arguments{'e'};
$newconfig = $arguments{'o'};

if($environment ne 'production' && $environment ne 'staging') {
    usage("Unknown environment specified: '$environment'. Must be one of 'staging' or 'production'.") ;
}
croak "Parameter file '$parameterfile' does not exist: $OS_ERROR" if ! -e $parameterfile;
#croak "Project directory '$projectdir' does not exist: $OS_ERROR" if -d $projectdir;

my $parameters = parseparams $parameterfile;
# Sanity check. Warn if less than two tags have been defined in the parameter file.
carp "Less than two paramaters read from $parameterfile, generating the config anyway" if(keys %parameters < 2);
my $replaced = genconfig $template, $newconfig;

carp "Nothing was replaced. Check $parameterfile and $template." if($replaced == 0)
