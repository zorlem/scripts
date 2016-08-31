#!/bin/bash
# A simple script to transfer the terminfo of the current terminal to a remote host

if [ -z "$1" ]; then
    echo "Please specify a destination ssh host";
    echo "Usage: $0 <hostname>";
    exit 1;
fi

#ssh $1 mkdir -p \~/.terminfo;
infocmp | ssh $1 'TMP=`mktemp` && cat > $TMP; tic -o .terminfo/ "$TMP" && rm "$TMP"';
