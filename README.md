# 短信转至Bark

`这是一个消息转发模块，主要用于转发安卓备用机上的手机卡接受到短信、未接来电后自动转发到苹果手机上的Bark应用`



# 配置说明

配置文件地址：`/data/adb/modules/Msg_2_Bark/config.conf`

```toml
#所有配置参数修改即时生效，无需重启！！！日志文件log.log

# Bark服务器地址 +「/push」，最后面的「/push」是推送时调用的接口名称
bark_url=https://api.day.app/push

# Bark推送key,进入Bark应用内查看
device_key=

# APP图标，不需要改
app_icon=https://images.app.goo.gl/b1sway3Ud6PkgUkWA

# 短信数据库路径，一般不需要改，如果你的设备的短信数据库路径不在这里请自行搜索
msg_db_path=/data/data/com.android.providers.telephony/databases/mmssms.db
# 通话记录数据库路径，一般不需要改，如果你的设备的通话记录数据库路径不在这里请自行搜索
call_db_path=/data/data/com.android.providers.contacts/databases/calllog.db

```



# 参考

- @top大佬（酷安）的 [消转模块](https://github.com/410154425/Message_Forwarding)
- [Bark官方说明文档](https://bark.day.app/#/?id=bark)
- [读取数据库可能需要依赖于sqlite3-magisk-module模块](https://github.com/rojenzaman/sqlite3-magisk-module)，已内置到本模块。
