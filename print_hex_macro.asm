macro print_hex(input) {
	variable t({input});
	variable d(0)
	variable div(1048576)//HEX 0x100000
	while div>0 {
		d=t/div%16;//get next digit
		div=div/16;
		if d<10 {
			print d;
		}
		if d==10 {
			print "A";
		}
		if d==11 {
			print "B";
		}
		if d==12 {
			print "C";
		}
		if d==13 {
			print "D";
		}
		if d==14 {
			print "E";
		}
		if d==15 {
			print "F";
		}
	}
}

macro pch() {
	putchar(9);
	print_hex(pc())
	print "\n"
}

macro pch(info) {
	putchar(9);
	print_hex(pc())
	putchar(9)
	print {info},"\n"
}
