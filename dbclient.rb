require "active_record"

# db = URI.parse(ENV['DATABASE_URL'] || 'postgres://localhost/mydb')

# ActiveRecord::Base.establish_connection(
#   :adapter => db.scheme == 'postgres' ? 'postgresql' : db.scheme,
#   :host => db.host,
#   :username => db.user,
#   :password => db.password,
#   :database => db.path[1..-1],
#   :encoding => 'utf8'
# )

ActiveRecord::Base.establish_connection(
	:adapter=>"sqlite3",
	:database=>"main.sqlite3"
)

class User < ActiveRecord::Base
	def self.isvalid?(pcode)
		curr = nil
		all.each do |user|
			curr = user if user.pcode == pcode
		end

		if curr.nil?
			return false
		else
			return false if (curr.openid.nil? or curr.openid.size == 0)		
		end
	
		true
	end

	def self.openid2 (pcode)
		all.each do |user|
			return user if user.pcode == pcode
		end
	end
	
	def self.register?(openid)
		all.each {|user| return true if openid == user.openid}
		
		false
	end
	
	def self.register_openid(pcode, token, openid)
		flag = false
		all.each do |user| 
			if user.pcode == pcode &&  user.token == token
				user.openid = openid
				flag = true if user.save
			end
		end
		
		flag
	end
end

class AddUser < ActiveRecord::Migration
	def self.up
		create_table :users do |t|
			t.string :pcode
			t.string :token
			t.string :openid
		end
	end

	def self.down
		drop_table :users
	end
end

if not User.table_exists?
	AddUser.up
end

#seed data
if User.where("pcode = 'Axxxxxxxxxxxxx'").size == 0
	u = User.new
	u.pcode = 'xxxxxxx'
	u.token = 'xxxxxxxxxx'
	u.save
end
if User.where("pcode = 'jxxxxxxxxxg'").size == 0
	u = User.new
	u.pcode = 'xxxxxxx'
	u.token = 'xxxxxxxxxxxx'
	u.save
end