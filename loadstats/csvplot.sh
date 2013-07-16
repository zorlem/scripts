#!/bin/bash
INPUT="";
OUTPUT="/dev/stdout";
COLS=""; 
GTEMPLATE="";
PNGNAME="";
YLABEL="";
TITLE="";

declare -a columns;
declare -a labels;

function usage() {
	exec 1>&2-
        echo
        echo "usage: ${0##*/} <-i file.csv> [-o file.gnuplot] [-c col1,col3,...] [options...]"
        echo " -i <file.csv>    CSV file to use as input (data separated by whitespace"
        echo " -o <file.gplot>  A file to be used for saving the gnuplot script, default: stdout"
        echo " -g <tmpl.gplot>  A gnuplot template to be included in the gnuplot script."
        echo "                  if this option is not specified a default template will be used";
        echo " -l <YLabel>      Set the label for the Y axis";
        echo " -t <title>       Set the title of the chart";
        echo " -n <graph.png>   Set the name for the output graph. PNG extension will be added";
        echo "                  automatically. If you don't specify this by default title is used.";
        echo "                  If no title is given then the name is the INPUT file name with PNG";
        echo "                  suffix added.";
        echo " -h		This text";
        echo
	exec 2>&1-
}

function err() {
	echo $1 1>&2-;
}

while getopts "hi:o:c:g:l:t:" flag; do
        case $flag in
		h)	usage;
			exit;
			;;
                i)      INPUT=$OPTARG
                        ;;
                o)      OUTPUT=$OPTARG
                        ;;
                c)      COLS=$OPTARG
                        ;;
                g)      GTEMPLATE=$OPTARG
                        ;;
                l)      YLABEL=$OPTARG
                        ;;
                n)      PNGNAME=$OPTARG
                        ;;
                t)      TITLE=$OPTARG
                        ;;
                *)      usage;
                        exit 1;
        esac
done


   
if [ -z "$INPUT" ]; then
        err "You need to specify an input CSV file using -i.";
        usage;
        exit 1;
fi

if [ ! -r "$INPUT" ]; then
        err "Error: file $INPUT should exist and must be readable";
        exit 1;
fi

if [ -z "$PNGNAME" ]; then
        # if no pngname is specified try using the title
        if [ -z "$TITLE" ]; then
                PNGNAME="$INPUT-graph.png";
        else
                PNGNAME="$TITLE.png";       
        fi
else
        if ! echo $PNGNAME | egrep -iq "png$"; then 
                PNGNAME=$PNGNAME.png
        fi
fi
                

function getheader() {
        # first line to an array
        labels=("" `head -n1 $INPUT | sed -e 's/,/\t/g'`); 
}

function printgtemplate() {
        if [ -n "$GTEMPLATE" -a ! -r "$GTEMPLATE" ]; then
                err "Unable to read gnuplot template file $GTEMPLATE";
                exit 1;
        fi
        if [ -z "$GTEMPLATE" ]; then
                cat > $OUTPUT <<- EOD
			set terminal png enhanced font "DejaVuSans,8" size 800,500
			set xlabel "time"
			set ylabel "$YLABEL"
			set data style lines 
			set datafile separator ",";
			set xdata time
			set timefmt "%Y-%m-%d %H:%M:%S"
			set format x "%d.%m.%Y\n%H:%M"
			#set xtics format "%s"
			set key outside bottom horizontal
			set title "$TITLE" font "DejaVuSans,12";
			set output "$PNGNAME"
		EOD

 
        else
                cat $GTEMPLATE;
        fi
}

function plotrow() {
        echo -n "\"$INPUT\" using 1:$1 title \"${labels[$1]}\"" >> $OUTPUT;
}

function parsecol() {
        if [ -n "$COLS" ]; then
                columns=( `echo $COLS | sed -e 's/,/\t/g'` )
        else
		# we skip the first column, it's the timestamp
                columns=( `seq 2 $((${#labels[*]}-1))` );
        fi
}

function plot() {
	c=0;
	echo -n "plot " >> $OUTPUT
	for i in ${columns[@]}; do
		plotrow $i;
		# do not print the comma if we've reached the last row
		if [ "$((++c))" -lt ${#columns[*]} ]; then
			echo -n ', ' >> $OUTPUT;
		fi
	done
}

# main part :)
getheader;
parsecol;
printgtemplate;
plot;
