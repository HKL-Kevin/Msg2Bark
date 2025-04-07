until [ $(getprop sys.boot_completed) -eq 1 ] ; do
  sleep 5
done
sleep 1
MODDIR=${0%/*}
chmod 0755 "$MODDIR/mf.sh"
chmod 0644 "$MODDIR/config.conf"
sleep 1
up=1
while :;
do
"$MODDIR/mf.sh" > /dev/null 2>&1
up="$(( $up + 1 ))"
sleep 1
done
