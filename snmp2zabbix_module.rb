require 'nokogiri'
require 'csv'
require 'date'

require 'securerandom'
def get_uuid; SecureRandom.uuid.gsub("-", ""); end

module SNMP2Zabbix
	
	MIB2C_CONFIG = """#Copyright 2020 Sean Bradley https://sbcode.net/zabbix/
	#Licensed under the Apache License, Version 2.0
	#@open -@
	@foreach $s scalar@
	*** scalar, $s, $s.decl, $s.objectID, $s.module, $s.parent, $s.subid, $s.enums, \"$s.description\" ***
			@foreach $LABEL, $VALUE enum@
	*** enum, $LABEL, $VALUE, " " ***
			@end@
	@end@
	@foreach $t table@
	*** table, $t, $t.decl, $t.objectID, $t.module, $t.parent, $t.subid, $t.enums, \"$t.description\" ***
			@foreach $i index@
	*** index, $i, $i.decl, $i.objectID, $i.module, $i.parent, $i.subid, $i.enums, \"$i.description\" ***
					@foreach $LABEL, $VALUE enum@
	*** enum, $LABEL, $VALUE, " " ***
					@end@
			@end@
			@foreach $i nonindex@
	*** nonindex, $i, $i.decl, $i.objectID, $i.module, $i.parent, $i.subid, $i.enums, \"$i.description\" ***
					@foreach $LABEL, $VALUE enum@
	*** enum, $LABEL, $VALUE, " " ***
					@end@
			@end@
	@end@
	"""

	
	DATATYPES = {
		"U_LONG": "",  # translates to Numeric (unsigned) in Zabbix
		"U64": "",  # translates to Numeric (unsigned) in Zabbix
		"OID": "CHAR",
		"U_CHAR": "CHAR",
		"LONG": "FLOAT",
		"CHAR": "TEXT",
		"IN_ADDR_T": "TEXT"
	}

	def self.get_snmp2zabbix_conf(path = __FILE__)
		
		local_snmp2zabbix_conf = File.dirname(File.expand_path(path)) + '/snmp2zabbix.conf'
		snmp2zabbix_conf = local_snmp2zabbix_conf

		unless File.exists?("snmp2zabbix.conf")
			unless File.exists?(local_snmp2zabbix_conf)

				File.open("snmp2zabbix.conf", "w") do |f|
					f.write(MIB2C_CONFIG)
				end
				snmp2zabbix_conf = 'snmp2zabbix.conf'
			end
		else
			snmp2zabbix_conf = 'snmp2zabbix.conf'
		end
		
		return snmp2zabbix_conf
	end

	def self.get_mib2c_command(mib_file, base_oid, mibdirs: '', snmp2zabbix_conf: get_snmp2zabbix_conf)
		mib_path = File.expand_path("..", mib_file).to_s
		mibs_env = 'MIBS="+' + mib_file + '"'
		mibdirs_env = 'MIBDIRS="+' + File.expand_path("..", mib_file).to_s + ' =>' + mib_path + '"'
		mib2c_command = "#{mibs_env} #{mibdirs_env} mib2c -c #{snmp2zabbix_conf} #{base_oid}"
		# mib2c_command = "pwd"
		return mib2c_command
	end

	def self.get_mib2c_data(mib_file, base_oid, mibdirs: '', snmp2zabbix_conf: get_snmp2zabbix_conf)
		mib2c_data = ''
		IO.popen(get_mib2c_command(mib_file, base_oid, mibdirs: mibdirs, snmp2zabbix_conf: snmp2zabbix_conf)) { |f|
			mib2c_data = f.read
		} rescue nil
		puts 'mib2c_data'
		puts mib2c_data
		return mib2c_data
	end



	def self.get_data_type(s)
		data_type = "TEXT"
		data_type = DATATYPES[s.upcase] if DATATYPES.keys.include?(s.upcase)
			
		# else:
		# 	print("Unhandled data type [" + s + "] so assigning TEXT")
		
		# if data type is INTEGER or other unsigned int, then don't create the node since zabbix will assign it the default which is already unsigned int
		data_type.size > 0 ? data_type : nil
	end

	def self.remove_colons(s); s.gsub("::", " "); end

	def self.get_last_enum_name(row); row[4].strip() + "::" + row[1].strip(); end



	def self.mib2c_data_scan(mib2c_data)

		# puts mib2c_data

		@scalars = []
		@enums = {}
		@last_enum_name = ""  # the one that is being built now
		@discovery_rules = {}
		@last_discovery_rule_name = ""  # the one that is being built now

		it = mib2c_data.scan /\*\*\* (.*?[^\*\*\*]*?) \*\*\*/sm

		it.each do |l|
			line = l[0]
			# puts "line"
			# puts line
			groups = line.scan /.*\"([^\"]*)\"/
			description = ""
			if groups
				if groups[0] && groups[0][0]
					description = groups[0][0].gsub('"', "").gsub('\\n', '&#13;').gsub('<', '&lt;').gsub('>', '&gt;').gsub(/\s+/, ' ').strip
				end
		
				# reader = line.split(",").map(&:strip)
				reader = CSV.new(line, liberal_parsing: true)
				# puts 'line'
				# puts line.inspect
				# puts 'reader'
				# puts reader.inspect
				reader.each do |row|
					# puts 'row'
					# puts row.inspect
					if row.size > 0
						begin
							case row[0]
							when "scalar"
								# puts 'scalar'
								# print("scaler:\t" + row[4].strip() + "::" +
								#       row[1].strip() + "\t" + row[3].strip() + ".0")
								@last_enum_name = get_last_enum_name(row)
								scalar = [
									@last_enum_name, 
									"#{row[3].strip}.0", 
									get_data_type(row[2].strip), 
									description
								]
								@scalars << scalar

							when "table"
								# print("table:\t" + row[4].strip() + "::" +
								#       row[1].strip() + "\t" + row[3].strip())
								@last_enum_name = get_last_enum_name(row)
								discovery_rule = [
									@last_enum_name, 
									row[3].strip(), 
									[], 
									description
								]
								# @discovery_rules[@last_enum_name] = [] unless @discovery_rules.include?(@last_enum_name)
								@discovery_rules[@last_enum_name] ||= []
								@discovery_rules[@last_enum_name] << discovery_rule
								@last_discovery_rule_name = @last_enum_name
		
							when "enum"
								# print("enum:\t" + row[1].strip() + "=" + row[2].strip())
								# @enums[@last_enum_name] = [] unless @enums.include? @last_enum_name
								@enums[@last_enum_name] ||= []
								@enums[@last_enum_name] << [row[1].strip(), row[2].strip()]
								#print("enum " + @last_enum_name + " " + row[1].strip() + " " + row[2].strip())
		
							when "index"
								# print(
								#     "index:\t" + row[4].strip() + "::" + row[1].strip() + "\t" + row[3].strip())
								@last_enum_name = get_last_enum_name(row)
		
							when "nonindex"
								# print(
								#     "nonindex:\t" + row[4].strip() + "::" + row[1].strip() + "\t" + row[3].strip())
								if row[7].to_i == 1
									# print(row)
									#print("is an enum title : " + row[4].strip() + "::" + row[1].strip())
									@last_enum_name = get_last_enum_name(row)
									column = [
										@last_enum_name, 
										row[3].strip(),
										get_data_type(row[2].strip()), 
										description, 
										@last_enum_name
									]
									if @last_discovery_rule_name == ""
										@last_discovery_rule_name = row[4].strip() + "::" + row[5].strip()
										unless @discovery_rules.include?(@last_discovery_rule_name)
											@discovery_rules[@last_discovery_rule_name] = []
											#print("need to create discovery rule")
											discovery_rule = [
												row[4].strip() + "::" + row[5].strip(), 
												row[3].strip(), 
												[], 
												description
											]
											@discovery_rules[@last_discovery_rule_name] << discovery_rule
										end
									end
									@discovery_rules[@last_discovery_rule_name][0][2] << column
		
								else
									# print(row)
									column = [
										get_last_enum_name(row),
										row[3].strip(), 
										get_data_type(row[2].strip()), 
										description
									]
									# print(description)
									# print(len(@discovery_rules[@last_discovery_rule_name][0][2]))
									if @last_discovery_rule_name.empty?
										@last_discovery_rule_name = row[4].strip() + "::" + row[5].strip()
										unless @discovery_rules.include? @last_discovery_rule_name
											@discovery_rules[@last_discovery_rule_name] = []
											#print("need to create discovery rule")
											discovery_rule = [
												row[4].strip() + "::" + row[5].strip(), 
												row[3].strip(), 
												[], 
												description
											]
											@discovery_rules[@last_discovery_rule_name] << discovery_rule
										end
									end
									@discovery_rules[@last_discovery_rule_name][0][2] << column
								end
							end
							# else:
							#     print("not handled row")
							#     print(row)
							
						rescue Exception => ex  # KeyError:
							#print("KeyError Exception.\nThis tends to happen if your MIB file cannot be found. Check that it exists. Or, your Base OID may be to specific and not found within the MIB file you are converting.\nChoose a Base OID closer to the root.\nEg, If you used 1.3.6.1.4.1, then try 1.3.6.1.4.\nIf the error still occurs, then try 1.3.6.1.\nNote that using a Base OID closer to the root will result in larger template files being generated.")
							# exit()
							puts "Exception : #{ex.inspect}"
						end
					end
				end
			end
		end


		return {
			scalars: @scalars,
			enums: @enums,
			discovery_rules: @discovery_rules
		}

	end


	def self.construct_json(scalars: [], enums: {}, discovery_rules: {}, mib_name: '' )
		
		# TODO
		@scalars = scalars
		@enums = enums
		puts 
		puts 
		puts 
		puts 
		# puts (@discovery_rules = discovery_rules)
		puts @discovery_rules[@discovery_rules.keys.first][0][2].size
		@mib_name = mib_name
		
		
		scalars_json = []
		# if @scalars&.size > 0
		if @scalars&.size&.positive?
			scalars_json = @scalars&.map do |s|
				{
					'uuid' => get_uuid,
					'name' => s[0],
					# 'type' => "SNMPV2",
					'type' => "SNMP_AGENT",
					# 'snmp_community' => "{$SNMP_COMMUNITY}",
					'snmp_oid' => s[1],
					'key' => s[1],

					'value_type' => s[2],

					'description' => s[3],
					'delay' => "1h",
					'history' => "2w",
					'trends' => "0",

					# 'applications' => [
					# 	{'name' => @mib_name}
					# ],
					'status' => "DISABLED",
				}.compact
			end
		end


		discovery_rules_json = [] 
		if @discovery_rules&.keys&.size&.positive?
			snmp_oids = ""

			discovery_rules_json = @discovery_rules&.keys&.map do |name|
				#TODO: WTF
				# puts @discovery_rules[name][0][2].size
				dr = @discovery_rules[name][0]
				{
					'uuid' => get_uuid,
					'name' => name,
					'description' => dr[3],
					'delay' => '3600',
					'key' => dr[1],
					# 'snmp_oid' => dr[1],
					# 'port' => "{$SNMP_PORT}",
					# 'snmp_community' => "{$SNMP_COMMUNITY}",
					# 'type' => "SNMPV2",
					'type' => "SNMP_AGENT",

					'item_prototypes' => dr[2]&.map { |item_proto|
						snmpoid2_append = "{##{item_proto[0].split("::")[1].upcase}},#{item_proto[1]},"
						snmp_oids += snmpoid2_append if (snmp_oids + snmpoid2_append).size < 501

						valuemap = item_proto[4] ? {'name' => item_proto[4]} : nil

						{
							'uuid' => get_uuid,
							'name' => "#{item_proto[0]}[{#SNMPINDEX}]",
							# 'type' => "SNMPV2",
							'type' => "SNMP_AGENT",
							'description' => item_proto[3],

							# 'applications' => [
							# 	{'name' => @mib_name}
							# ],
							
							# 'port' => "{$SNMP_PORT}",
							# 'snmp_community' => "{$SNMP_COMMUNITY}",
							'key' => "#{item_proto[1]}[{#SNMPINDEX}]",
							'snmp_oid' => "#{item_proto[1]}.{#SNMPINDEX}",

							'delay' => "1h",
							'history' => "2w",
							'trends' => "0",

							'value_type' => item_proto[2],

							'valuemap' => valuemap
						}.compact # </item_prototype>
					}, # item_prototypes: dr[2].map { |item_proto|

					# 'snmp_oid' => (snmp_oids.empty? ? nil : "discovery[#{snmp_oids[0...-1]}]") 
					'snmp_oid' => (snmp_oids.empty? ? dr[1] : "discovery[#{snmp_oids[0...-1]}]") 
				}.compact # </discovery_rule>
			end #discovery_rules_json = @discovery_rules.keys.map do |name|
		end

		valuemaps_json = []
		if @enums&.keys&.size&.positive?
			valuemaps_json = @enums&.keys&.map { |name|
				{
					'uuid' => get_uuid,
					"name" => name,
					"mappings" => @enums[name].map { |mapping|
						{
							"newvalue" => mapping[0],
							"value" => mapping[1] 
						}
					}
				}
			}
		end

		json = {
			'zabbix_export' => {
				'version' => '5.4',
				'date' => Time.now.strftime("%FT%TZ"),

				'templates' => [
					{
						'uuid' => get_uuid,
						'template' => "Template SNMP #{remove_colons(@mib_name)}",
						'name' => "Template SNMP #{remove_colons(@mib_name)}",
						# 'applications' => [
						# 	{'name' => @mib_name}
						# ],
						'description' => "Created By SNMP2ZABBIX.rb at https://github.com/ack43/SNMP2ZABBIX",
						'groups' => [
							{'name' => "Templates"}
						],

						'items' => scalars_json,

						'macros' => [
							{
								'macro' => "{$SNMP_PORT}",
								'value' => '161'
							}
						],

						'discovery_rules' => discovery_rules_json,

						'valuemaps' => valuemaps_json

					}
				] # templates: [
			}
		}

		return json

	end

	def self.construct_yaml(scalars: [], enums: {}, discovery_rules: {}, mib_name: '' )

		require 'yaml'
		params = {
			scalars: scalars,
			enums: enums,
			discovery_rules: discovery_rules,
			mib_name: mib_name
		}
		construct_json(**params).to_yaml
	end


	def self.construct_xml(scalars: [], enums: {}, discovery_rules: {}, mib_name: '' )

		# TODO
		@scalars = scalars
		@enums = enums
		@discovery_rules = discovery_rules
		@mib_name = mib_name

		# <description>Created By Sean Bradley's SNMP2ZABBIX.py at https://github.com/Sean-Bradley/SNMP2ZABBIX</description>
		Nokogiri::XML::Builder.new do |xml|
			xml.send(:zabbix_export) do |zabbix_export|
				zabbix_export.send :version, 5.2
				zabbix_export.send :templates do |templates|
					templates.send :template do |template|
						template.send :template, "Template SNMP #{remove_colons(@mib_name)}"
						template.send :name, "Template SNMP #{remove_colons(@mib_name)}"
						template.send :applications do |applications|
							applications.send :application do |application|
								application.send :name, @mib_name
							end
						end
						template.send :description, "Created By SNMP2ZABBIX.rb at https://github.com/ack43/SNMP2ZABBIX"
						template.send :groups do |groups|
							groups.send :group do |group|
								group.send :name, "Templates"
							end
						end

						# if @scalars&.size > 0
						if @scalars&.size&.positive?
							template.send :items do |items|
								@scalars.each do |s|
									items.send :item do |item|
										item.send :name, s[0]
										item.send :type, "SNMPV2"
										item.send :snmp_community, "{$SNMP_COMMUNITY}"
										item.send :snmp_oid, s[1]
										item.send :key, s[1]
										
										item.send :value_type, s[2] if s[2]
										
										item.send :description, s[3]
										item.send :delay, "1h"
										item.send :history, "2w"
										item.send :trends, "0"

										item.send :applications do |applications|
											applications.send :application do |application|
												application.send :name, @mib_name
											end
										end
										item.send :status, "DISABLED"
									end # item
								end #@scalars.each do |s|
							end # items
						end #if @scalars&.size > 0

						template.send :macros do |macros|
							macros.send :macro do |macro|
								macro.send :macro, "{$SNMP_PORT}"
								macro.send :value, 161
							end
						end

						# if @discovery_rules&.size > 0
						if @discovery_rules&.size&.positive?
							snmp_oids = ""
							template.send :discovery_rules do |discovery_rules|
								@discovery_rules.keys.each do |name|
									discovery_rules.send :discovery_rule do |discovery_rule|
										discovery_rule.send :name, name
										@discovery_rules[name].each do |dr|
											discovery_rule.send :description, dr[3]
											discovery_rule.send :delay, '3600'
											discovery_rule.send :key, dr[1]
											discovery_rule.send :port, "{$SNMP_PORT}"
											discovery_rule.send :snmp_community, "{$SNMP_COMMUNITY}"
											discovery_rule.send :type, "SNMPV2"

											discovery_rule.send :item_prototypes do |item_prototypes|
												dr[2].each do |item_proto|
													item_prototypes.send :item_prototype do |item_prototype|
														item_prototype.send :name, "#{item_proto[0]}[{#SNMPINDEX}]"
														item_prototype.send :type, "SNMPV2"
														item_prototype.send :description, item_proto[3]

														item_prototype.send :applications do |applications|
															applications.send :application do |application|
																application.send :name, @mib_name
															end
														end
														item_prototype.send :port, "{$SNMP_PORT}"
														item_prototype.send :snmp_community, "{$SNMP_COMMUNITY}"
														item_prototype.send :key, "#{item_proto[1]}[{#SNMPINDEX}]"
														item_prototype.send :snmp_oid, "#{item_proto[1]}.{#SNMPINDEX}"

														item_prototype.send :delay, "1h"
														item_prototype.send :history, "2w"
														item_prototype.send :trends, "0"

														item_prototype.send :value_type, item_proto[2] if item_proto[2]

														item_prototype.send :valuemap do |valuemap|
															valuemap.send :name, item_proto[4]
														end

													end # item_prototype

													snmpoid2_append = "{##{item_proto[0].split("::")[1].upcase}},#{item_proto[1]},"
													snmp_oids += snmpoid2_append if (snmp_oids + snmpoid2_append).size < 501

												end #dr[2].each do |item_proto|
											end # item_prototypes

											discovery_rule.send :snmp_oid, "discovery[#{snmp_oids[0...-1]}]" unless snmp_oids.empty?
										end#@discovery_rules[name].each do |dr|
									end # discovery_rule
								end #@discovery_rules.keys.each do |name|
							end # discovery_rules
						end #if @discovery_rules&.size > 0



					end
				end
				
			end
		end
	end



end