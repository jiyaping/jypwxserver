#encoding:utf-8

require 'sinatra'
require './dbclient.rb'
require './wxlib.rb'
require './seed.rb'

wx = WX.new

get '/' do
	#403 unless valid_request?
	params["echostr"]
end

post "/" do
	content_type :xml, 'charset' => 'utf-8'
	
	signature = params["signature"]
	timestamp = params["timestamp"]
	nonce = params["nonce"]
	echostr = params["echostr"]

	if signature and timestamp and nonce and echostr
		403 unless signature == wx.checkSignature([timestamp, nonce])
	else
		403
	end
	
	result = MsgHandler.process(request.body.read)

	return result
end

get "/token/get" do
	wx.get_token

	return $token_info["access_token"]
end

get "/token/force_get" do
	wx.get_token(true)

	return $token_info["access_token"]
end

get "/token/show" do
	$token_info["access_token"]
end

get "/menu/create" do
	(wx.create_menu).body
end

get "/menu/delete" do
	(wx.delete_menu).body
end

get "/zhiban" do 
	str=<<SRC

SRC
	
	return str
end

get "/menu/get" do
	(wx.get_menu).body
end
 
error 403 do
  'Access forbidden'
end

not_found do
	'the page not found on my server'
end

helpers do
	def valid_request?
		signature = params["signature"]
		timestamp = params["timestamp"]
		nonce = params["nonce"]
		echostr = params["echostr"]

		if signature and timestamp and nonce and echostr
			return true if signature == wx.checkSignature([timestamp, nonce])
		end

		return false
	end
end
