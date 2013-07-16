{
	if($14 ~ /Mbit/) { 
		div=1024*1024; 
	}
	if($14 ~ /Kbit/) {
		div=1024; 
	}
	if($14 ~ /[[:digit:]]+bit/) { 
		div=1;
	}
	gsub(/[MK]?bit/,"",$14);
	rate=$14*div;
	tot=tot+rate;
}
END {
	print "Total: " tot/1024 "Kbit/s"
}
