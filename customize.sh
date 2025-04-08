bindir=/system/bin

if [ ! -f "$bindir/sqlite3" ]; then
	ui_print "[0/3] Keeping necessary binary file: $MODPATH$xbindir/sqlite3.$ARCH"
	cp $MODPATH$bindir/sqlite3.$ARCH $MODPATH$bindir/sqlite3.keep

	ui_print "[1/3] Deleting unnecessary binary files"
	rm -f $MODPATH$bindir/sqlite3.arm $MODPATH$bindir/sqlite3.arm64 $MODPATH$bindir/sqlite3.x64 $MODPATH$bindir/sqlite3.x86

	ui_print "[2/3] Restoring necessary binary file to $MODPATH$xbindir/sqlite3"
	mv $MODPATH$bindir/sqlite3.keep  $MODPATH$bindir/sqlite3

	ui_print "[3/3] Installed to $bindir"

	set_perm_recursive $MODPATH 0 0 0755 0755

	chmod 0755 "$MODPATH$bindir/sqlite3"
else
	ui_print "The sqlite3 is already present."
	rm -rf "$MODPATH/system"
fi
