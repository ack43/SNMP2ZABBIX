# Ported from python
if ARGV.count < 2
	puts "need MIB file and base OID"
	return 1
end


mib_file = ARGV[0].to_s

base_oid = ARGV[1].to_s

mib_name = File.basename(mib_file).split(".")[0].gsub(" ", "_")

output_file = ARGV[2]
_format = if output_file
	output_file.split(".").last
else
	"xml"
end


require_relative 'snmp2zabbix_module'
include SNMP2Zabbix

mib2c_data = SNMP2Zabbix.get_mib2c_data mib_file, base_oid, snmp2zabbix_conf: SNMP2Zabbix.get_snmp2zabbix_conf(__FILE__)
mib2c_structure = SNMP2Zabbix.mib2c_data_scan mib2c_data
mib2c_structure[:mib_name] = mib_name
# xml = SNMP2Zabbix.construct_xml **mib2c_structure
output = case _format
when 'yaml', 'yml'
	SNMP2Zabbix.construct_yaml **mib2c_structure
when 'json'
	SNMP2Zabbix.construct_json **mib2c_structure
when 'xml'
	SNMP2Zabbix.construct_xml **mib2c_structure
end


if ARGV.count < 3
	File.open("template_" + mib_name + ".xml", "w") do |xml_file|
		xml_file.write(output.to_xml)
	end

elsif ARGV[2] == '-o'
	print(xml.to_xml)

else
	File.open(ARGV[2], "w") do |_file|
		_file.write(output)
	end
end


# XML = """<?xml version="1.0" encoding="UTF-8"?>
# <zabbix_export>
# 	<version>5.4</version>
# 	<templates>
# 		<template>
# 			<template>Template SNMP """ + removeColons(MIB_NAME) + """</template>
# 			<name>Template SNMP """ + removeColons(MIB_NAME) + """</name>
# 			<applications>
# 					<application>
# 							<name>""" + MIB_NAME + """</name>
# 					</application>
# 			</applications>
# 			<description>Created By SNMP2ZABBIX.py at https://github.com/ack43/SNMP2ZABBIX</description>
# 			<groups>
# 					<group>
# 							<name>Templates</name>
# 					</group>
# 			</groups>
# """

# # @scalars
# # if @scalars.count > 0:
# if len(@scalars) > 0:
#     XML += """            <items>
# """
# for s in @scalars:
#     XML += """                <item>
#                     <name>""" + s[0] + """</name>
#                     <type>SNMPV2</type>
#                     <snmp_community>{$SNMP_COMMUNITY}</snmp_community>
#                     <snmp_oid>""" + s[1] + """</snmp_oid>
#                     <key>""" + s[1] + """</key>
# """
#     if s[2] is not None:
#         XML += """                    <value_type>""" + s[2] + """</value_type>
# """
#     XML += """                    <description>""" + s[3] + """</description>
#                     <delay>1h</delay>
#                     <history>2w</history>
#                     <trends>0</trends>               
#                     <applications>
#                         <application>
#                             <name>""" + MIB_NAME + """</name>
#                         </application>
#                     </applications>
#                     <status>DISABLED</status>
#                 </item>
# """
# # if @scalars.count > 0:
# if len(@scalars) > 0:
#     XML += """            </items>
# """


# # Add Macros
# XML += """            <macros>
#                 <macro>
#                     <macro>{$SNMP_PORT}</macro>
#                     <value>161</value>
#                 </macro>
#             </macros>
# """

# # DISCOVERY RULES
# if len(@discovery_rules):
#     SNMPOIDS = ""
#     XML += """            <discovery_rules>
# """
#     for x in @discovery_rules:
#         XML += """                <discovery_rule>
#                     <name>""" + x + """</name>
# """
#         for y in @discovery_rules[x]:
#             XML += """                    <description>""" + y[3] + """</description>
#                     <delay>3600</delay>
#                     <key>""" + y[1] + """</key>
#                     <port>{$SNMP_PORT}</port>
#                     <snmp_community>{$SNMP_COMMUNITY}</snmp_community>
#                     <status>DISABLED</status>
#                     <type>SNMPV2</type>
#                     <item_prototypes>
# """
#             for z in y[2]:
#                 XML += """                        <item_prototype>
#                             <name>""" + z[0] + """[{#SNMPINDEX}]</name>
#                             <type>SNMPV2</type>
#                             <description>""" + z[3] + """</description>
#                             <applications>
#                                 <application>
#                                     <name>""" + MIB_NAME + """</name>
#                                 </application>
#                             </applications>
#                             <port>{$SNMP_PORT}</port>
#                             <snmp_community>{$SNMP_COMMUNITY}</snmp_community>
#                             <key>""" + z[1] + """.[{#SNMPINDEX}]</key>
#                             <snmp_oid>""" + z[1] + """.{#SNMPINDEX}</snmp_oid>
#                             <delay>1h</delay>
#                             <history>2w</history>
#                             <trends>0</trends>
# """
#                 if z[2] is not None:
#                     XML += """                            <value_type>""" + z[2] + """</value_type>
# """
#                 if len(z) >= 5:
#                     XML += """                            <valuemap>
#                                 <name>""" + z[4] + """</name>
#                             </valuemap>
# """
#                 SNMPOID2APPEND = "{#" + \
#                     z[0].split("::")[1].upper() + "}," + z[1] + ","
#                 if(len(SNMPOIDS + SNMPOID2APPEND) < 501):
#                     SNMPOIDS += SNMPOID2APPEND
#                 XML += """                        </item_prototype>
# """
#             XML += """                    </item_prototypes>
#                     <snmp_oid>discovery[""" + SNMPOIDS[:-1] + """]</snmp_oid>
# """
#         XML += """                </discovery_rule>
# """
# if len(@discovery_rules):
#     XML += """            </discovery_rules>
# """

# XML += """        </template>
#     </templates>
# """

# #@enums
# if len(@enums):
#     XML += """    <value_maps>
# """
#     for x in @enums:
#         XML += """        <value_map>
#             <name>""" + x + """</name>
#             <mappings>
# """
#         for y in @enums[x]:
#             XML += """                <mapping>
#                     <newvalue>""" + y[0] + """</newvalue>
#                     <value>""" + y[1] + """</value>
#                 </mapping>
# """
#         XML += """            </mappings>
#         </value_map>
# """
# if len(@enums):
#     XML += """    </value_maps>
# """


# # Finish the XML
# XML += "</zabbix_export>"

# if len(sys.argv) < 4:
#     with open("template_" + MIB_NAME + ".xml", "w") as xml_file:
#         xml_file.write(XML)

# else: 
#     if sys.argv[3] == '-o':
#         print(XML)

#     else:
#         with open(sys.argv[3], "w") as _file:
#             _file.write(XML)

# # print("Done")
# # return 0
