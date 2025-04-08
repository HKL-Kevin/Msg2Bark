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
	bark_url="$(echo "$config_conf" | egrep '^bark_url=' | sed -n 's/bark_url=//g;$p')"
	device_key="$(echo "$config_conf" | egrep '^device_key=' | sed -n 's/device_key=//g;$p')"
	bark_post="{\"title\": \"$MF_app\", \"body\": \"$wx_text\",\"level\": \"active\",\"volume\": 5,\"badge\": 1,\"device_key\": \"$device_key\",\"subtitle\":\"[$msg_date]\",\"group\": \"$MF_app\"}"
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

winxin_push(){
        content=$(echo -e "$1" | tr '\n' '\\' | sed 's/\\/\\n/g' | tr '\r' '\\r' | sed 's/\\ //g')
        webhook="$(echo "$config_conf" | egrep '^wx_webhook=' | sed -n 's/wx_webhook=//g;$p')"
        web_post="{\"msgtype\": \"text\",\"text\": {\"content\":\"$content\",\"mentioned_list\":[\"@all\"]}"
        web_push="$(curl -s --connect-timeout 12 -m 15 -H 'Content-Type: application/json' -d "$web_post" "$webhook")"
        if [ -n "$web_push" ]; then
                errcode="$(echo "$web_push" | egrep '\"errcode\"' | sed -n 's/ //g;s/.*\"errcode\"://g;s/\".*//g;s/,.*//g;$p')"
                if [ "$errcode" = "0" ]; then
                        echo "$(date +%F_%T) 【微信群机器人通道 发送成功】：$content" >> "$MODDIR/log.log"
                else
                        echo "$(date +%F_%T) 【微信群机器人通道 发送失败】：错误提示：$web_push。【消息】：$content" >> "$MODDIR/log.log"
                fi
        else
                echo "$(date +%F_%T) 【微信群机器人通道 发送失败】：访问接口失败，或是请检查配置参数[wx_webhook]是
否填写正确。【消息】：$content" >> "$MODDIR/log.log"
        fi
}

forwarding(){
        # 执行查询并将结果逐行存储到变量
        MSG_DB_PATH="$(echo "$config_conf" | egrep '^msg_db_path=' | sed -n 's/msg_db_path=//g;$p')"
        if [ -f "$MSG_DB_PATH" ]; then
        	sqlite3 -separator $'\t' "$MSG_DB_PATH" "SELECT _id, address, date, read FROM sms WHERE type = 1 AND read = 0 LIMIT 1;" | while IFS=$'\t' read -r sms_id address timestamp is_read; do
			# 将日期从毫秒转换为秒，并格式化为可读的日期格式
			formatted_date=$(date -d "@$(echo "$timestamp / 1000" | bc)" "+%m-%d %H:%M:%S")
			# 查询消息体
			body=$(sqlite3 "$MSG_DB_PATH" "SELECT body FROM sms WHERE type = 1 AND _id = $sms_id")
			# 推送Bark消息
			bark_switch="$(echo "$config_conf" | egrep '^bark_switch=' | sed -n 's/bark_switch=//g;$p')"
                        if [ "$bark_switch" != "0" ]; then
                                bark_push "$address" "$formatted_date" "$body" "短信"
                        fi
			# 推送企业微信群机器人消息
			wx_switch="$(echo "$config_conf" | egrep '^wx_switch=' | sed -n 's/wx_switch=//g;$p')"
                        if [ "$wx_switch" != "0" ]; then
				content="类型：未读短信 \n号码：$address \n时间：$formatted_date \n内容：\n\n$body"
				winxin_push "$content"
                        fi
			# 更新为已读状态
			if [ "$wx_switch" != "0" ] || [ "$bark_switch" != "0" ]; then
				sqlite3 "$MSG_DB_PATH" "UPDATE sms SET read = $R_ED WHERE type = 1 AND _id = $sms_id;"
			fi
		done
        fi
        
}

callReport(){
# 执行查询并将结果逐行存储到变量
	CALL_DB_PATH="$(echo "$config_conf" | egrep '^call_db_path=' | sed -n 's/call_db_path=//g;$p')"
	if [ -f "$CALL_DB_PATH" ]; then
		sqlite3 -separator $'\t' "$CALL_DB_PATH" "SELECT _id, number, date, new FROM calls WHERE type = 3 AND new = 1 LIMIT 1;" | while IFS=$'\t' read -r call_id number timestamp is_read; do
			# 将日期从毫秒转换为秒，并格式化为可读的日期格式
			formatted_date=$(date -d "@$(echo "$timestamp / 1000" | bc)" "+%m-%d %H:%M:%S")

			# 推送Bark消息
			bark_switch="$(echo "$config_conf" | egrep '^bark_switch=' | sed -n 's/bark_switch=//g;$p')"
                        if [ "$bark_switch" != "0" ]; then
                                bark_push "$number" "$formatted_date" "未接来电" "电话"
                        fi
                        # 推送企业微信群机器人消息
			wx_switch="$(echo "$config_conf" | egrep '^wx_switch=' | sed -n 's/wx_switch=//g;$p')"
                        if [ "$wx_switch" != "0" ]; then
				content="类型：未接来电 \n号码：$number \n时间：$formatted_date"
				winxin_push "$content"
                        fi
			# 更新为已读状态
			if [ "$wx_switch" != "0" ] || [ "$bark_switch" != "0" ]; then
				sqlite3 "$CALL_DB_PATH" "UPDATE calls SET new = 0 WHERE type = 3 AND _id = $call_id;"
			fi
		done
	fi
}

forwarding
callReport

