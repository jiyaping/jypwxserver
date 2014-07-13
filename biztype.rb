# encoding : utf-8

require 'csv'
require "./pinyin_array.rb"

$type_rule = {
	# "Duty"=> [/值班/,/duty/,/zhiban/],
	"Phone"=> [/(^\d\d{10}|\d{5}$|^(A|B|N|W|S|Y|a|b|n|w|s|y)\d{5}|[a-zA-Z]{6,20}|^[a-zA-Z]{4}|[\u4E00-\u9FA5]{2,5})/],
	"CookBook"=>[/(吃|eat|menu|cook|早餐|晚餐|午餐|早饭|晚饭|中饭)/],
}

$csv_data_path = "data"

class TypeManager
	def self.reply(str)
		arr = which(str)

		result = []
		arr.each do |key|
			result += search(key.downcase, str)
		end

		result
	end

	def self.which(str)
		str.encode!('utf-8')
		arr = []

		$type_rule.map do |k, v|
			v.each do |item|
				(arr<< k and break) if str =~ item
			end
		end

		return arr
	end

	def self.search(type, str)
		data = eval("@@#{type.to_s}")

		result = []
		data.each do |k, v|
			result<< v if k =~ /#{str.downcase}/
		end

		result
	end

	def self.setup
		@@phone = read_csv_data('phone')
	end

	def self.autosetup
		arr = []
		Dir.entries("#{File.join(File.dirname(__FILE__), $csv_data_path)}").each do |f|
			if f.end_with? ".csv"
				mstr = /[a-zA-Z]+/.match(f).to_s 
				arr << mstr unless arr.index(mstr)
			end
		end

		arr.each do |model|
			eval("@@#{model} = read_csv_data('#{model}')")
		end
	end

	def self.read_csv_data(modelname, path = $csv_data_path)
		model = eval(modelname.capitalize!)
		arr = {}
		Dir.entries("#{File.join(File.dirname(__FILE__), path)}").each do |f|
			if f.start_with? modelname.downcase and f.end_with? ".csv"
				arr.merge! read_single_csv(model, f)
			end
		end

		return arr
	end

	def self.read_single_csv(model, filename, path = $csv_data_path)
		hash = {}
		file = File.join(File.dirname(__FILE__), path, filename)
		#file_windows = File.new(file, "r:windows-1250")
		CSV.foreach(file, :headers=> true,encoding: "utf-8") do |row|
			obj = model.new(row)
			hash[obj.get_key] = obj
		end

		return hash
	end

	def self.phone
		@@phone
	end
end

class BaseType
	def get_key
		str = ''
		instance_variables.each do |attr|
			str<< " #{instance_variable_get(attr)}"
		end

		(str.encode('utf-8') + convert2pinying(str).encode('utf-8') +\
		 " #{four_key} ".encode('utf-8') + (rand*1000).to_i.to_s).downcase.encode('utf-8')
	end

	#private

	def convert2pinying(str='')
		result = ''
		str.encode('utf-8').each_char do |item|
			result << chinese(item)
		end

		result
	end

	def chinese(c='')
		temp = $pinyintable[c]
		temp.nil?? c : temp
	end

	def four_key
		''
	end
end

class Phone < BaseType
	attr_accessor :job_code, :username, :user_py, :dep_name, :oa_se_mobile, :oa_mobile

	def initialize(arr)
		@job_code = arr['USER_CODE']
		@username = arr['USER_NAME']
		@user_py = arr['ENGLISH_NAME']
		@dep_name = arr['SUBJECTNAME']
		@oa_se_mobile = arr['OA_SE_MOBILE']
		@oa_mobile = arr['OA_MOBILE']
	end

	def four_key
		temp = @username.encode('utf-8')
		result = case temp.size
			when 2
				chinese(temp[0])[0..1] + chinese(temp[1])[0..1]
			when 3
				chinese(temp[0])[0..1] + chinese(temp[1])[0] + chinese(temp[2])[0]
			when 4
				chinese(temp[0])[0] + chinese(temp[1])[0] +\
				chinese(temp[2])[0] + chinese(temp[3])[0]
			else
				''
			end

		return result
	end

	def to_str(sepsize=20)
		str=<<SRC
#{@job_code}/#{@username}
#{@oa_se_mobile}
#{@dep_name}
#{'-'*sepsize}
SRC
		return str.encode('utf-8')
	end
end

class CookBook < BaseType
end

class Duty < BaseType
	def self.data
		@@data
	end

	def self.init_data
		@@data = []

		File.readlines("#{File.join($csv_data_path, "duty.txt")}").each do |line|
			@@data << (line.encode("utf-8").split("\t").map{|item| item.delete("\n")})
		end
	end

	def self.today
		day = Time.now.day

		return day(day)
	end

	def self.yesterday
		day = Time.now.day  - 1

		return day(day)
	end

	def self.tomorrow
		day = Time.now.day + 1

		return day(day)
	end

	def self.choose(inc)
		daytime = Time.now.day + inc

		return day(daytime)
	end

	def self.day(day, month=Time.now.month)
		duty_list = []
		person = person_list(day, month)

		person.each_with_index.each do |v, i|
			duty_list<< [@@comment[i], v, get_phone(v)]
		end

		format(duty_list)
	end

	def self.format(arr)
		str="当日值班如下:".encode("utf-8")

		arr.each do |item|
			str<< "\n#{item[0]}/#{item[1]}/#{item[2]}".encode("utf-8")
		end

		str
	end

	def self.person_list(day, month=Time.now.month)
		arr = []

		@@data.each do |item|
			person = item[day-1]

			unless person.nil?
				arr<< person.encode("utf-8")
			end	

		end

		arr
	end

	def self.get_phone(name)
		if TypeManager.phone.nil?
			return ""
		end

		persons = TypeManager.phone.select{|k, v| v.username == name}

		if persons.values.size == -0
			return ""
		end

		return persons.values.first.oa_se_mobile
	end

	@@comment = [
		"干部",
		"白班",
		"白班",
		"晚班",
		"晚班",
		"网络",
		"P C",
		"小机",
		"应用",
		"DBA",
	]
end