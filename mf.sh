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
	web_post="{\"msgtype\": \"text\",\"text\": {\"content\":\"$content\",\"mentioned_list\":[\"@all\"]}}"
	web_push="$(curl -s --connect-timeout 12 -m 15 -H 'Content-Type: application/json' -d "$web_post" "$webhook")"
	if [ -n "$web_push" ]; then
		errcode="$(echo "$web_push" | egrep '\"errcode\"' | sed -n 's/ //g;s/.*\"errcode\"://g;s/\".*//g;s/,.*//g;$p')"
		if [ "$errcode" = "0" ]; then
			echo "$(date +%F_%T) 【微信群机器人通道 发送成功】：$content" >> "$MODDIR/log.log"
		else
			echo "$(date +%F_%T) 【微信群机器人通道 发送失败】：错误提示：$web_push。【消息】：$content" >> "$MODDIR/log.log"
		fi
	else
		echo "$(date +%F_%T) 【微信群机器人通道 发送失败】：访问接口失败，或是请检查配置参数[wx_webhook]是否填写正确。【消息】：$content" >> "$MODDIR/log.log"
	fi
}

wx_pusher(){
	content=$(echo -e "$1" | tr '\n' '\\' | sed 's/\\/\\n/g' | tr '\r' '\\r' | sed 's/\\ //g')
	
	# 获取wxpusher配置
	appToken="$(echo "$config_conf" | egrep '^wxpusher_token=' | sed -n 's/wxpusher_token=//g;$p')"
	topicId="$(echo "$config_conf" | egrep '^wxpusher_topic=' | sed -n 's/wxpusher_topic=//g;$p')"
	
	# 如果没有设置topicId，则使用默认值39910
	if [ -z "$topicId" ]; then
		topicId="39910"
	fi
	
	summary="短信通知" # 可选，消息摘要
	contentType=2 # HTML格式
	url="" # 可选，原文链接
	verifyPayType=0 # 不验证订阅时间

	# 构建JSON数据
	json_data="{\"appToken\": \"$appToken\", \"content\": \"$content\", \"contentType\": $contentType, \"summary\": \"$summary\", \"topicIds\": [\"$topicId\"], \"verifyPayType\": $verifyPayType}"
	
	# 发送POST请求
	web_push=$(curl -s --connect-timeout 12 -m 15 -H 'Content-Type: application/json' -d "$json_data" "https://wxpusher.zjiecode.com/api/send/message")
	web_push=$(echo "$web_push" | tr -d '\n\r' | sed 's/ //g')
	# 解析返回结果
	if [ -n "$web_push" ]; then
		code=$(echo "$web_push" | grep -o '"code":[^,}]*' | awk -F: '{print $2}' | head -n 1)
		echo "wxpusher code:$code"
		if [ "$code" = "1000" ]; then
			echo "$(date +%F_%T) 【WxPusher通道 发送成功】：$content" >> "$MODDIR/log.log"
		else
			error_msg=$(echo "$web_push" | grep -o '"msg": *"[^"]*"' | awk -F'"' '{print $4}')
			echo "$(date +%F_%T) 【WxPusher通道 发送失败】：错误提示：$error_msg。【消息】：$content" >> "$MODDIR/log.log"
		fi
	else
		echo "$(date +%F_%T) 【WxPusher通道 发送失败】：访问接口失败，请检查配置参数[wxpusher_token,wxpusher_topic]是否填写正确。【消息】：$content" >> "$MODDIR/log.log"
	fi
}

forwarding(){
    startTime="$(echo "$config_conf" | egrep '^startTime=' | sed -n 's/startTime=//g;$p')"
    if [ -z "$startTime" ]; then
		startTime="2025-04-22"
	fi
	MSG_DB_PATH="$(echo "$config_conf" | egrep '^msg_db_path=' | sed -n 's/msg_db_path=//g;$p')"
	if [ -f "$MSG_DB_PATH" ]; then
	    
		sqlite3 -separator $'\t' "$MSG_DB_PATH" "SELECT _id, address, date, read FROM sms WHERE type = 1 AND read = 0 AND DATETIME(date / 1000, 'unixepoch') || '.' || (date % 1000)>'$startTime' LIMIT 1;" | while IFS=$'\t' read -r sms_id address timestamp is_read; do
			formatted_date=$(date -d "@$(echo "$timestamp / 1000" | bc)" "+%m-%d %H:%M:%S")
			body=$(sqlite3 "$MSG_DB_PATH" "SELECT body FROM sms WHERE type = 1 AND _id = $sms_id")
			
			bark_switch="$(echo "$config_conf" | egrep '^bark_switch=' | sed -n 's/bark_switch=//g;$p')"
			if [ "$bark_switch" != "0" ]; then
				bark_push "$address" "$formatted_date" "$body" "短信"
			fi
			
			wx_switch="$(echo "$config_conf" | egrep '^wx_switch=' | sed -n 's/wx_switch=//g;$p')"
			if [ "$wx_switch" != "0" ]; then
				content="类型：未读短信 \n号码：$address \n时间：$formatted_date \n内容：\n\n$body"
				winxin_push "$content"
			fi
			
			wxpusher_switch="$(echo "$config_conf" | egrep '^wxpusher=' | sed -n 's/wxpusher=//g;$p')"
			if [ "$wxpusher_switch" != "0" ]; then
				# 对于wxpusher，我们发送HTML格式的消息
				html_content="<h3>未读短信通知</h3><p><strong>号码：</strong>$address</p><p><strong>时间：</strong>$formatted_date</p><p><strong>内容：</strong></p><pre>$body</pre>"
				wx_pusher "$html_content"
			fi
			
			if [ "$wx_switch" != "0" ] || [ "$bark_switch" != "0" ] || [ "$wxpusher_switch" != "0" ]; then
				sqlite3 "$MSG_DB_PATH" "UPDATE sms SET read = $R_ED WHERE type = 1 AND _id = $sms_id;"
			fi
		done
	fi
}

callReport(){
    startTime="$(echo "$config_conf" | egrep '^startTime=' | sed -n 's/startTime=//g;$p')"
    if [ -z "$startTime" ]; then
		startTime="2025-04-22"
	fi
	CALL_DB_PATH="$(echo "$config_conf" | egrep '^call_db_path=' | sed -n 's/call_db_path=//g;$p')"
	if [ -f "$CALL_DB_PATH" ]; then
		sqlite3 -separator $'\t' "$CALL_DB_PATH" "SELECT _id, number, date, new FROM calls WHERE type = 3 AND new = 1 AND DATETIME(date / 1000, 'unixepoch') || '.' || (date % 1000)>'$startTime' LIMIT 1;" | while IFS=$'\t' read -r call_id number timestamp is_read; do
			formatted_date=$(date -d "@$(echo "$timestamp / 1000" | bc)" "+%m-%d %H:%M:%S")
			
			bark_switch="$(echo "$config_conf" | egrep '^bark_switch=' | sed -n 's/bark_switch=//g;$p')"
			if [ "$bark_switch" != "0" ]; then
				bark_push "$number" "$formatted_date" "未接来电" "电话"
			fi
			
			wx_switch="$(echo "$config_conf" | egrep '^wx_switch=' | sed -n 's/wx_switch=//g;$p')"
			if [ "$wx_switch" != "0" ]; then
				content="类型：未接来电 \n号码：$number \n时间：$formatted_date"
				winxin_push "$content"
			fi
			
			wxpusher_switch="$(echo "$config_conf" | egrep '^wxpusher=' | sed -n 's/wxpusher=//g;$p')"
			if [ "$wxpusher_switch" != "0" ]; then
				html_content="<h3>未接来电通知</h3><p><strong>号码：</strong>$number</p><p><strong>时间：</strong>$formatted_date</p>"
				wx_pusher "$html_content"
			fi
			
			if [ "$wx_switch" != "0" ] || [ "$bark_switch" != "0" ] || [ "$wxpusher_switch" != "0" ]; then
				sqlite3 "$CALL_DB_PATH" "UPDATE calls SET new = 0 WHERE type = 3 AND _id = $call_id;"
			fi
		done
	fi
}

forwarding
callReport
