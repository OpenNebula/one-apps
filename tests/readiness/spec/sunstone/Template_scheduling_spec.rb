require 'init_functionality'
require 'sunstone_test'
require 'sunstone/Template'

RSpec.describe "Sunstone vm template tab", :type => 'skip' do
  year = Time.new.year + 1

	before(:all) do
		user = @client.one_auth.split(":")
		@auth = {
			:username => user[0],
			:password => user[1]
		}

		@sunstone_test = SunstoneTest.new(@auth)
		@sunstone_test.login
		@template = Sunstone::Template.new(@sunstone_test)
	end

	before(:each) do
		sleep 1
	end

	after(:all) do
		@sunstone_test.sign_out
	end

	it "should create a template with scheduled actions" do
		template_name = "temp_sched"
		if @template.navigate_create({ name: template_name })
			@template.add_general({ name: template_name })
			scheduling = {
				actions: [
				{ 
					action: "hold",
					date: {
						day: "15",
						month: "June",
						year: year
					}, 
					time: "02:00", 
					relative: false,
					periodic: false
				},
				{
					action: "terminate",
					date: {
						day: "15",
						month: "June",
						year: year
					},
					time: "02:00",
					relative: false,
					periodic: true,
					days_week: ["mon"]
				},
				{ 
					action: "poweroff",
					date: "2",
					time: "years",
					relative: true,
					periodic: false
				},
				{
					action: "terminate-hard",
					date: {
						day: "15",
						month: "June",
						year: year
					},
					time: "02:00",
					relative: false,
					periodic: true,
					repeat: "week", 
					days_week: ["mon", "thu"] 
				},
				{
					action: "reboot",
					date: {
						day: "15",
						month: "June",
						year: year
					},
					time: "02:00",
					relative: false,
					periodic: true,
					repeat: "week", 
					days_week: ["mon", "thu"],
					periodic_date: {
						day: "16",
						month: "June",
						year: year
					}
				},
				{
					action: "reboot-hard",
					date: {
						day: "15",
						month: "June",
						year: year
					},
					time: "02:00",
					relative: false,
					periodic: true,
					repeat: "week", 
					days_week: ["mon", "thu"],
					after_time: {
						day: "3600"
					}
				},
				{ 
					action: "stop",
					date: {
						day: "15",
						month: "June",
						year: year
					},
					time: "02:00",
					relative: false,
					periodic: true,
					repeat: "month", 
					days_month: "1,7,11"
				}
				]
			}
			@template.add_sched(scheduling)
			@template.submit
		end

		#Check template created with scheduled actions
		@sunstone_test.wait_resource_create("template", template_name)
		tmp_xml = cli_action_xml("onetemplate show -x '#{template_name}'") rescue nil
		htime =  Time.new(year,6,15,0,0,0)

		# check no-periodic hold action
		expect(tmp_xml['TEMPLATE/SCHED_ACTION[ACTION="hold"]/TIME']).to eql "#{htime.to_i}"
		
		# check no-periodic terminate action
		expect(tmp_xml['TEMPLATE/SCHED_ACTION[ACTION="terminate"]/TIME']).to eql "#{htime.to_i}"
		expect(tmp_xml['TEMPLATE/SCHED_ACTION[ACTION="terminate"]/END_TYPE']).to eql "0"

		# check relative time poweroff action
		expect(tmp_xml['TEMPLATE/SCHED_ACTION[ACTION="poweroff"]/TIME']).to eql "+63072000"

		# check periodic terminate-hard action
		expect(tmp_xml['TEMPLATE/SCHED_ACTION[ACTION="terminate-hard"]/TIME']).to eql "#{htime.to_i}"
		expect(tmp_xml['TEMPLATE/SCHED_ACTION[ACTION="terminate-hard"]/DAYS']).to eql "1,4"
		expect(tmp_xml['TEMPLATE/SCHED_ACTION[ACTION="terminate-hard"]/REPEAT']).to eql "0" # weekly

		# check periodic reboot action
		end_time =  Time.new(year,6,16,12,0,0)
		expect(tmp_xml['TEMPLATE/SCHED_ACTION[ACTION="reboot"]/TIME']).to eql "#{htime.to_i}"
		expect(tmp_xml['TEMPLATE/SCHED_ACTION[ACTION="reboot"]/DAYS']).to eql "1,4"
		expect(tmp_xml['TEMPLATE/SCHED_ACTION[ACTION="reboot"]/END_VALUE']).to eql "#{end_time.to_i}"
		expect(tmp_xml['TEMPLATE/SCHED_ACTION[ACTION="reboot"]/END_TYPE']).to eql "2"

		# check periodic reboot-hard action
		expect(tmp_xml['TEMPLATE/SCHED_ACTION[ACTION="reboot-hard"]/TIME']).to eql "#{htime.to_i}"
		expect(tmp_xml['TEMPLATE/SCHED_ACTION[ACTION="reboot-hard"]/DAYS']).to eql "1,4"
		expect(tmp_xml['TEMPLATE/SCHED_ACTION[ACTION="reboot-hard"]/END_VALUE']).to eql "3600"

		# check periodic stop action
		expect(tmp_xml['TEMPLATE/SCHED_ACTION[ACTION="stop"]/TIME']).to eql "#{htime.to_i}"
		expect(tmp_xml['TEMPLATE/SCHED_ACTION[ACTION="stop"]/DAYS']).to eql "1,7,11"
		expect(tmp_xml['TEMPLATE/SCHED_ACTION[ACTION="stop"]/REPEAT']).to eql "1" # monthly
	end
end
