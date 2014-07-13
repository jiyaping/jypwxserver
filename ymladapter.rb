require 'yaml'

class WxUser
	@@data = YAML::load_file("data/#{self.to_s.downcase}s.yml")
	
	def self.valid?(pcode)
		openid = openid(pcode)['openid']
		return false if (openid.nil? or openid.size=="")
		
		true
	end
	
	def self.openid (pcode)
		@@data.each do |t|
			return t if t['pcode'] == pcode
		end
	end
	
	def self.register?(openid)
		@@data.each {|user| return true if openid == user['openid']}
		
		false
	end
	
	def self.register_openid(pcode, token, openid)
		flag = false
		@@data.each do |user| 
			if user['pcode'] == pcode &&  user['token'] == token
				user['openid'] = openid and flag = true
			end
		end
		
		return File.open("data/#{self.to_s.downcase}s.yml", 'w') {|f| f.write @@data.to_yaml} if flag
		
		flag
	end
end