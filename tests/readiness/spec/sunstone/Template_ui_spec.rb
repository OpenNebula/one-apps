require 'init_functionality'
require 'sunstone_test'
require 'sunstone/Template'
require 'base64'

RSpec.describe "Sunstone vm template tab", :type => 'skip' do

    # Returns VM template
	def vm_template
		<<-EOF
			NAME   = vm_template
			CPU    = 1
			MEMORY = 128
		EOF
	end

    # Returns user inputs
	def user_inputs
		[
			{
				name: "mytext",
				type: "text",
				desc: "description mytext",
				default: { value: "default mytext" },
				post: { value: "mytext" },
			},
			{
				name: "mytext64",
				type: "text64",
				desc: "description mytext64",
				mand: "false",
				default: { value: "default mytext64" },
				post: { value: "mytext64" },
			},
			{
				name: "mynumber",
				type: "number",
				desc: "description mynumber",
				default: { value: "10" },
				post: { value: "5" },
			},
			{
				name: "mynumberfloat",
				type: "number-float",
				desc: "description mynumber (float)",
				mand: "false",
				default: { value: "10.5" },
				post: { value: "5.5" },
			},
			{
				name: "myrange",
				type: "range",
				desc: "description myrange",
				default: { min: "1", max: "10", value: "5" },
				post: { value: "7" },
			},
			{
				name: "myrangefloat",
				type: "range-float",
				desc: "description myrange (float)",
				mand: "false",
				default: { min: "1", max: "10", value: "5.5" },
				post: { value: "7.5" },
			},
			{
				name: "mylist",
				type: "list",
				desc: "description mylist",
				default: { options: "optA,optB,optC,optD", value: "optB" },
				post: { select: "optA" },
			},
			{
				name: "mymultiple",
				type: "list-multiple",
				desc: "description mylist (multiple)",
				mand: "false",
				default: { options: "optA,optB,optC,optD", value: "optC" },
				post: { select: "optB,optC" },
			},
			{
				name: "mypassword",
				type: "password",
				desc: "description mypassword",
				post: { value: "mypassword" }
			},
			{
				name: "myboolean",
				type: "boolean",
				desc: "description myboolean",
				mand: "false",
				default: { value: "YES" },
				post: { value: "NO" },
			}
		]
	end

	before(:all) do
		# Create VM template
		template = vm_template()
        @template_id = cli_create("onetemplate create", template)

        user = @client.one_auth.split(":")
        @auth = {
            :username => user[0],
            :password => user[1]
        }

        @sunstone_test = SunstoneTest.new(@auth)
        @template = Sunstone::Template.new(@sunstone_test)

		@sunstone_test.login
    end

    before(:each) do
        sleep 1
    end

    after(:all) do
        @sunstone_test.sign_out
    end

    it "should add user inputs to vm template" do
        @template.navigate_update("vm_template")
        @template.update_user_inputs(user_inputs)

        @template.submit

        # Check template updated
        @sunstone_test.wait_resource_update(
			"template",
			"vm_template",
			{
				:key=>"TEMPLATE/USER_INPUTS/MYTEXT",
				:value=>"M|text|description mytext| |default mytext"
			}
		)

		tmp = cli_action_xml("onetemplate show -x 'vm_template'") rescue nil

		user_inputs.each { |input|
			mandatory = input[:mand] == "false" ? 'O' : 'M'
			type = input[:type]
			name = input[:name].upcase
			description = input[:desc]
			default = input[:default]

			if default
				if default[:min] && default[:max]
					params = "#{default[:min]}..#{default[:max]}"
				elsif default[:options]
					params = default[:options]
				elsif default[:value]
					params = " "
				end

				expect(tmp["TEMPLATE/USER_INPUTS/#{name}"]).to eql "#{mandatory}|#{type}|#{description}|#{params}|#{default[:value]}"
			else
				expect(tmp["TEMPLATE/USER_INPUTS/#{name}"]).to eql "#{mandatory}|#{type}|#{description}"
			end
		}
	end
	
	it "should check default values on instantiation form" do
		@template.navigate_instantiate("vm_template")

		user_inputs.each { |input|
			xpath_form_instantiate = "//*[@id = 'instantiateTemplateDialogWizard']"
			xpath_field = "#{xpath_form_instantiate}//*[@wizard_field = '#{input[:name].upcase}']"

			field = $driver.find_element(:xpath, xpath_field)
			field_value = field.attribute("value") if field

			input_default = input[:default]
			if input_default
				expect(field_value).to eql input_default[:value].to_s
			end
		}
	end

	it "should check values in the vm context" do
		if @template.navigate_instantiate("vm_template")
			@template.fill_user_inputs(user_inputs)
			@template.submit
		end

		@sunstone_test.wait_resource_create("vm", "vm_template-0")

		tmp = cli_action_xml("onevm show -x 'vm_template-0'") rescue nil

		user_inputs.each { |input|
			type = input[:type]
			name = input[:name].upcase
			post = input[:post]
			
			if post[:select]
				context_value = post[:select]
			elsif post[:value]
				context_value = post[:value]
				context_value = Base64.encode64(context_value).strip if type == "text64"
			end

			expect(tmp["TEMPLATE/CONTEXT/#{name}"]).to eql context_value
		}
    end
end
