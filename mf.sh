#!bin/sh

MODDIR=${0%/*}
if [ -f "$MODDIR/disable" ]; then
	exit 0
fi
config_conf="$(cat "$MODDIR/config.conf" | egrep -v '^#')"


# 数据库路径
R_ED=1 # 短信已读状态码
UN_R=0 # 短信未读状态码


bark_push() {
	cell=$1
	msg_date=$2
	MF_app=$4
	wx_text=$cell:$(echo -e "$3" | tr '\n' '\\' | sed 's/\\/\\n/g' | tr '\r' '\\r' | sed 's/\\ //g')
	app_icon="$(echo "$config_conf" | egrep '^app_icon=' | sed -n 's/app_icon=//g;$p')"
	bark_url="$(echo "$config_conf" | egrep '^bark_url=' | sed -n 's/bark_url=//g;$p')"
	device_key="$(echo "$config_conf" | egrep '^device_key=' | sed -n 's/device_key=//g;$p')"
	bark_post="{\"title\": \"$MF_app\",\"icon\": \"$app_icon\", \"body\": \"$wx_text\",\"level\": \"active\",\"volume\": 5,\"badge\": 1,\"device_key\": \"$device_key\",\"subtitle\":\"[$msg_date]\",\"group\": \"$MF_app\"}"
	bark_push="$(curl -s --connect-timeout 12 -m 15 -H 'Content-Type: application/json' -d "$bark_post" "$bark_url")"
	if [ -n "$bark_push" ]; then
		bark_push_errcode="$(echo "$bark_push" | egrep '\"code\"' | sed -n 's/ //g;s/.*\"code\"://g;s/\".*//g;s/,.*//g;$p')"
		if [ "$bark_push_errcode" = "200" ]; then
			echo "$(date +%F_%T) 【Bark通道 发送成功】：$wx_text" >> "$MODDIR/log.log"
		else
			echo "$(date +%F_%T) 【Bark通道 发送失败】：请检查配置参数[bark_url,device_key]是否填写正确，返回提示：$bark_push。【消息】：$wx_text" >> "$MODDIR/log.log"
		fi
	else
		echo "$(date +%F_%T) 【Bark通道 发送失败】：访问接口失败，或是请检查配置参数[bark_url]是否填写正确，返回提示：$bark_push。【消息】：$wx_text" >> "$MODDIR/log.log"
	fi
}

forwarding(){
        # 执行查询并将结果逐行存储到变量
        MSG_DB_PATH="$(echo "$config_conf" | egrep '^msg_db_path=' | sed -n 's/msg_db_path=//g;$p')"
        if [ ! -f $MSG_DB_PATH ];then
        	echo "$(date +%F_%T) 通话记录数据库不存在，请正确配置 $MSG_DB_PATH" >> "$MODDIR/log.log"
        else
        	sqlite3 -separator $'\t' "$MSG_DB_PATH" "SELECT _id, address, date, read FROM sms WHERE type = 1 AND read = 0 LIMIT 1;" | while IFS=$'\t' read -r sms_id address date is_read; do
			# 将日期从毫秒转换为秒，并格式化为可读的日期格式
			formatted_date=$(date -d @$((date / 1000)) "+%Y-%m-%d %H:%M:%S")
			# 查询消息体
			body=$(sqlite3 "$MSG_DB_PATH" "SELECT body FROM sms WHERE type = 1 AND _id = $sms_id")
			# 推送消息
			bark_push "$address" "$formatted_date" "$body" "短信"
			# 更新为已读状态
			sqlite3 "$MSG_DB_PATH" "UPDATE sms SET read = $R_ED WHERE type = 1 AND _id = $sms_id;"
		done
	fi
}

callReport(){
        # 执行查询并将结果逐行存储到变量
        CALL_DB_PATH="$(echo "$config_conf" | egrep '^call_db_path=' | sed -n 's/call_db_path=//g;$p')"
        if [ ! -f $CALL_DB_PATH ];then
        	echo "$(date +%F_%T) 通话记录数据库不存在，请正确配置 $CALL_DB_PATH" >> "$MODDIR/log.log"
        else
        	sqlite3 -separator $'\t' "$CALL_DB_PATH" "SELECT _id, number, date, new FROM calls WHERE type = 3 AND new = 1 LIMIT 1;" | while IFS=$'\t' read -r call_id number date is_read; do
			# 将日期从毫秒转换为秒，并格式化为可读的日期格式
			formatted_date=$(date -d @$((date / 1000)) "+%Y-%m-%d %H:%M:%S")

			# 推送消息
			bark_push "$number" "$formatted_date" "未接来电" "电话"
			# 更新为已读状态
			sqlite3 "$CALL_DB_PATH" "UPDATE calls SET new = 0 WHERE type = 3 AND _id = $call_id;"
		done
	fi
}

forwarding
callReport
