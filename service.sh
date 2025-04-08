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
  if [ $((up % 60)) -eq 0 ]; then
    config_conf="$(cat "$MODDIR/config.conf" | egrep -v '^#')"
    MSG_DB_PATH="$(echo "$config_conf" | egrep '^msg_db_path=' | sed -n 's/msg_db_path=//g;$p')"
    if [ ! -f $MSG_DB_PATH ];then
      echo "$(date +%F_%T) 短信记录数据库不存在，请正确配置msg_db_path的值." >> "$MODDIR/log.log"
    fi
    CALL_DB_PATH="$(echo "$config_conf" | egrep '^call_db_path=' | sed -n 's/call_db_path=//g;$p')"
    if [ ! -f $CALL_DB_PATH ];then
      echo "$(date +%F_%T) 通话记录数据库不存在，请正确配置call_db_path的值." >> "$MODDIR/log.log"
    fi
    up=1
  fi
  "$MODDIR/mf.sh" >> "$MODDIR/run.log" 2>&1
  up="$(( $up + 1 ))"
  sleep 1
done
