#encoding:utf-8

ENV['SSL_CERT_FILE'] = File.expand_path(File.dirname(__FILE__)) + "/cacert.pem"
$token = 'xxxxx'
$appID = 'xxxxxxxxxxxxxxxx'
$appsecret = 'xxxxxxxxxxxxxxxxxxx'
$token_info = {"access_token"=> nil, "timestamp"=> Time.now.to_i}
$api_url = "api.weixin.qq.com/cgi-bin/"
$py_change_rule = {
	/^l/=>'n',
	/^n/=>'l',
	/ing$/=>'in',
	/in$/=>'ing'
}
$menu={
    "button"=> [
        {
            "type"=> "view",
            "name"=> "我们的地盘",
            "url"=>  "http://wx.wsq.qq.com/229721668"
        },
        {
            "type"=> "view",
            "name"=> "还没想好",
            "url"=>  "http://jyp-wxserver.heroku.com/zhiban"
        },
        {
           "name"=> "快捷",
           "sub_button"=> [
           {	
               "type"=> "click",
               "name"=> "关于",
               "key"=>"about_key"
            },
            {	
               "type"=> "click",
               "name"=> "帮助",
               "key"=>"help_key"
            },
            {
               "type"=> "click",
               "name"=> "菜谱",
               "key"=>"cookbook_key"
            },
            {
               "type"=> "click",
               "name"=> "值班",
               "key"=> "duty_key"
            }]
       }
    ]
}

$event_subscribe_reply_msg = "哇,被你发现了。这个账号，主要有下面这些用途:\n1)查电话。\n2)查菜谱。\
		\n3)查值班表。\n4)你也可以给我留言说你想要的功能。\n5)没有了5了。"
$event_help_reply_msg = "sorry啊。。。没时间写。再说吧"
$event_about_reply_msg = "这个账号呢是个人因为好奇开发的。纯属娱乐的，如有帮助，不胜荣幸:D"
