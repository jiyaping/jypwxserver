#encoding:utf-8

require "json"
require "net/http"
require "net/https"
require "nokogiri"
require "digest/sha1"
require "./config.rb"
require "./biztype.rb"
require "./ymladapter.rb"
require "./cmdhelper.rb"
require "./dbclient.rb"

puts "-----begin init data----"
TypeManager.setup
Duty.init_data
puts "-----end  init  data----"

class WX
	attr_accessor :wxclient

	def initialize
		@wxclient = WXHttpClient.new
		get_token #获取token
		create_menu #创建菜单
	end

	def get_token
		if token_valid?
			return $token_info["access_token"]
		end

		args = {
			grant_type: 'client_credential',
			appid: $appID,
			secret: $appsecret
		}

		resp = @wxclient.get_ssl("token", args)
		puts "-----#{Time.now}---#{resp.body}" 

		if resp.is_a? Net::HTTPSuccess
			update_token_info(JSON.parse(resp.body))
		end

		return $token_info
	end

	def checkSignature(arr)
		str = (arr<< $token).sort.inject(:+)

		Digest::SHA1.hexdigest(str)
	end

	def create_menu()
		args = {
			"access_token"=> $token_info["access_token"]
		}

		#create menu
		resp = @wxclient.post_ssl("menu/create", args, $menu.to_json)

		resp
	end

	def delete_menu()
		args = {
			"access_token"=> $token_info["access_token"]
		}
		resp = @wxclient.get_ssl("menu/delete", args)

		resp
	end

	def get_menu()
		args = {
			"access_token"=> $token_info["access_token"]
		}
		resp = @wxclient.get_ssl("menu/get", args)

		resp
	end

	private

	def update_token_info(hash)
		$token_info["access_token"] = hash["access_token"]
		$token_info["timestamp"] = Time.now.to_i

		return $token_info
	end

	def token_valid?
		if $token_info["access_token"].nil? or
			Time.now.to_i - $token_info["timestamp"] > 7000
			return false
		end

		return true
	end
end

class WXHttpClient
	attr_accessor :api_url

	def initialize(url = $api_url)
		@api_url = url
	end

	def get(path, params)
		uri = URI(File.join("http://#{api_url}", path))
		uri.query = URI.encode_www_form(params)

		resp = Net::HTTP.get_response(uri)

		resp
	end

	def post
	end

	def get_ssl(path, params)
		puts "--methods info--- #{params.inspect}"
		uri = URI.parse(File.join("https://#{api_url}", path))
		uri.query = URI.encode_www_form(params)
		puts "--uri info--- #{uri.inspect}"
		http = Net::HTTP.new(uri.host, uri.port)
		http.use_ssl = true

		request = Net::HTTP::Get.new(uri.request_uri)
		puts "--request info--- #{request.inspect}"
		resp = http.request(request)

		puts "-----#{Time.now}---#{resp.body}" 
		return resp
	end

	def post_ssl(path, args, body='')
		uri = URI.parse(File.join("https://#{api_url}", path))
		uri.query = URI.encode_www_form({"access_token"=>args["access_token"]}) if args["access_token"]
		puts "--uri info--- #{uri.inspect}"
		https = Net::HTTP.new(uri.host,uri.port)
		https.use_ssl = true
		req = Net::HTTP::Post.new(uri.request_uri)
		args.map do |k, v|
			req[k] = v
		end
		req.body = body
		puts "--request info--- #{req.inspect}"

		resp = https.request(req)
		puts "-----#{Time.now}---#{resp.body}" 
		resp
	end
end

class MsgHandler
	def self.process(str)
		xml_doc = Nokogiri::XML(str)
		#TODO to all kind of msg
		node = xml_doc.xpath("/xml//MsgType")
		return nil if node.size < 0 and node.children.size < 0

		msg = case node.children.text.to_sym
			when :text then TextMsg.new(xml_doc).reply{|msg| 
				result = ''
				if msg.whichcmd == :normal
					puts "in normal #{msg.FromUserName}"
					puts "end int normal"
					result = text_msg_process(msg.Content)
				elsif msg.whichcmd == :register
					result = msg.register
				elsif msg.whichcmd == :duty
					result = msg.duty
				end
				
				result = "你还没有注册,发送命令：\n reg 工号/TOKEN\n来注册。TOKEN需从管理员获取。" unless User.register? msg.FromUserName

				result
			}
			when :image then ImageMsg.new(xml_doc)
			when :voice then VoiceMsg.new(xml_doc).reply{|msg| voice_msg_process(msg.Recognition)}
			when :video then VideoMsg.new(xml_doc)
			when :location then LocationMsg.new(xml_doc) 
			when :link then LinkMsg.new(xml_doc)
			when :event then EventMsg.new(xml_doc).event_route()
			else UnknowMsg.new(xml_doc).reply{|msg| "没有这个功能啦。"}
		end
	end

	def self.text_msg_process(str)
		result = TypeManager.reply(str)

		temp = ''
		if result.size <= 0
			if not str =~ /[\u2E80-\u9FFF]/
				result = get_second_repy(str)
				if result.size <= 0
					return "sorry啦, 没有和#{str}相关信息。\n" 
				end
				temp += "我觉得你可能要找的是这些：\n"
			elsif str =~ /[\u2E80-\u9FFF]/
				result = get_second_repy(convert2pinying(str))
				if result.size <= 0
					return "sorry啦, 没有和#{str}相关信息。\n" 
				end
				temp += "我觉得你可能要找的是这些：\n"
			else
				return "sorry啦, 没有和#{str}相关信息。\n" 
			end
		elsif result.size > 10
			temp += "查到好多信息,你可以输入更加准确的信息来查找,只以下显示10条哦：\n"
		end

		result[0..10].each do |item|
			temp += item.to_str
		end

		return temp
	end

	def self.voice_msg_process(str)
		text_msg_process(convert2pinying(str))
	end

	def self.image_msg_process()

	end

	def self.common_msg_process()

	end

	def self.unkonw_msg_procces()

	end

	def self.convert2pinying(str='')
		result = ''
		str.encode('utf-8').each_char do |item|
			result << chinese(item)
		end

		result
	end

	def self.chinese(c='')
		temp = $pinyintable[c]
		temp.nil?? c : temp
	end

	def self.get_second_repy(str)
		arr = get_second_str3(str)
		result = []
		arr.each do |item|
			result |= TypeManager.reply(item)
		end

		result
	end
	
		
	def self.get_second_str3(str='')
		result = []
		arr = get_second_pinyin_arr2(str)
		arr.each do |item|
			result << get_single_str3(item)
		end
		
		cartprod(*result).map{|arr| arr.join('').delete('')}
	end

	def self.get_second_str2(str='')
		result = []
		arr = get_second_pinyin_arr2(str)

		arr.each do |item|
			$py_change_rule.each do |key, value|
				if item =~ key
					temp = item.sub(key, value)
					atom_py = arr.map{|v| v == item ? temp : v}.join("").delete(" ")
					result<< atom_py unless result.index(atom_py)
				end
			end
		end

		result
	end

	def self.get_unqiue_py(arr)

	end

	#using auto status change to get splited strings
	def self.get_second_pinyin_arr(str='')
		arr = []

		temp = ''
		status_last, status_curr = false, false
		(str<<' ').each_char do |chr|
			temp<< chr

			status_curr = is_atom_pinyin? temp
			if status_last and not status_curr
				arr<< temp[0...-1]
				temp = chr
				status_last, status_curr = false, false
			end

			status_last = status_curr
		end

		arr.delete("")
		arr
	end
	
	#2014-06-09 add get str second arr
	def self.get_single_str3(str='')
		arr = [str]
		while true
			last_arr = arr
			arr.each do |item|
				$py_change_rule.each do |rule_k,rule_v|
					changed = item.sub(rule_k, rule_v)
					arr<< changed unless arr.index(changed)
				end
			end
			
			last_arr.sort != arr.sort ? last_arr = arr : break
		end
		
		arr
	end

	#advance  method to split the pinyin
	def self.get_second_pinyin_arr2(str='')
		arr = []

		idx = 0
		str.size.times do
			temp, index = '', 0
			str.each_char do |chr|
				index += 1
				temp<< chr

				idx = index if is_atom_pinyin? temp  
			end

			arr<< str[0...idx]
			str = str[idx..-1]
			break if str.nil?
		end

		arr.delete("")
		arr
	end

	def self.is_atom_pinyin?(str)
		$pinyintable.values.index(str).nil?? false : true
	end

	def self.get_second_str(str)
		result = []
		pinyin_str = ' '
		#str.each_char do |c|
		#	pinyin_str<< chinese(c)<< ' '
		#end
		pinyin_str = " " + get_second_pinyin_arr2(str).join(' ') +" "
		while change_one(pinyin_str)
			temp = change_one(pinyin_str)
			if result.index(temp.delete(' '))
				break
			else
				result << temp.delete(' ')
			end
			pinyin_str = temp
		end

		return result
	end

	def self.change_one(str)
		$py_change_rule.map do |k, v|
			return str.sub(k, v) if str =~ k
		end

		return false
	end
	
	def self.cartprod(*args)
		result = [[]]
		while [] != args
			t, result = result, []
			b, *args= args
			t.each do |a|
				b.each do |n|
					result << a + [n]
				end
			end
		end
		
		result
	end
end

class Msg
	attr_accessor :ToUserName, :FromUserName, :CreateTime, :MsgType, :MsgId
	
	def initialize(xml_doc)
		@ToUserName = nil
		@FromUserName = nil
		@CreateTime = nil
		@MsgType = nil
		@MsgId = nil

		build(xml_doc)
	end

	def build(xml_doc)
		instance_variables.each do |attr|
			node = xml_doc.xpath("/xml//#{attr.to_s[1..-1].strip}")
			if node.size > 0 and node.children.size > 0
				instance_variable_set(attr, node.children.text) 
			end
		end
	end

	def reply(&biz)
		ctn = yield self
		
		str= <<STR
<xml>
	<ToUserName><![CDATA[#{@FromUserName}]]></ToUserName>
	<FromUserName><![CDATA[#{@ToUserName}]]></FromUserName>
	<CreateTime>#{Time.now.to_i}</CreateTime>
	<MsgType><![CDATA[text]]></MsgType>
	<Content><![CDATA[#{ctn}]]></Content>
</xml>
STR
		return str
	end
	
	private
end

class TextMsg < Msg
	attr_accessor :Content

	def initialize(str)
		@Content = nil
		super(str)
	end
	
	def whichcmd
		type = :normal
		
		if @Content =~ /(reg|register)/
			type = :register
		elsif @Content =~ /(zhiban|值班|duty)/
			type = :duty
		else 
			type = :normal
		end
		
		type
	end
	
	def register
		pcode = /\s*\w{6}\s*\//.match(@Content)
		token = /\/\s*\w{6,}\s*/.match(@Content)
		if pcode and token
			pcode = pcode.to_s.delete('/').strip
			token = token.to_s.delete('/').strip
			puts "---------#{pcode}------#{token}"
			if User.register_openid(pcode, token, @FromUserName)
				content = "注册成功 :D"
			else
				content = "工号或TOKEN不合法。"
			end
		else
			content = "输入不合法或者TOKEN已失效。"
		end
		
		return content
	end

	def duty
		str = ""
		matches = /(zhiban|值班|duty|)(\s*)(today|tomorrow|yesterday|-?\d+)?/.match @Content

		_, cmd, _, day = matches.to_a
		day = 0 if day.nil? 

		daytime = day.to_i if Integer(day) rescue false

		if day == "today"
			daytime = 0
		elsif day == "tomorrow"
			daytime = 1
		elsif day == "yesterday"
			daytime = -1
		end

		daytime = 0 if daytime.nil?
		return Duty.choose(daytime)
	end
end

class ImageMsg < Msg
	attr_accessor :PicUrl, :MediaId

	def initialize(str)
		@PicUrl = nil
		@MediaId = nil
		super(str)
	end
end

class VoiceMsg < Msg
	attr_accessor :Format, :MediaId, :Recognition

	def initialize(str)
		@Format = nil
		@MediaId = nil
		@Recognition = nil
		super(str)
	end
end

class VideoMsg < Msg
	attr_accessor :ThumbMediaId, :MediaId

	def initialize(str)
		@ThumbMediaId = nil
		@MediaId = nil
		super(str)
	end
end

class LocationMsg < Msg
	attr_accessor :Location_X, :Location_Y, :Scale, :Label

	def initialize(str)
		@Location_X = nil
		@Location_Y = nil
		@Scale = nil
		@Label = nil
		@MediaId = nil
		super(str)
	end
end

class LinkMsg < Msg
	attr_accessor :Title, :Description, :Url

	def initialize(str)
		@Title = nil
		@Description = nil
		@Url = nil
		super(str)
	end
end

class EventMsg < Msg
	attr_accessor :Event, :EventKey

	def initialize(str)
		@Event = nil
		@EventKey = nil

		super(str)
	end

	def event_route()
		if @Event == 'subscribe'
			subscribe()
		elsif @Event == 'CLICK'
			eval(@EventKey)
		elsif @Event == 'VIEW'
			''
		else
			unknow()
		end
	end

	def about_key()
		reply{|msg|
			$event_about_reply_msg
		}
	end

	def help_key()
		reply{|msg|
			$event_help_reply_msg
		}
	end

	def cookbook_key()
		reply{|msg|
			"nothing"
		}
	end

	def duty_key()
		reply{|msg|
			"nothing"
		}
	end

	def subscribe()
		reply{|msg|
			$event_subscribe_reply_msg
		}
	end

	def unknow()
		reply{|msg|
			'你想干嘛？ 我不是很懂。。。'
		}
	end
end

class UnknowMsg < Msg
	attr_accessor :Content

	def initialize(str)
		@Content = nil
		super(str)
	end
end