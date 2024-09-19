require 'init_functionality'
require 'sunstone_test'
require 'sunstone/Dashboard'

RSpec.describe "Sunstone dashboard tab", :type => 'skip' do

    before(:all) do
        user = @client.one_auth.split(":")
        @auth = {
            :username => user[0],
            :password => user[1]
        }

        @sunstone_test = SunstoneTest.new(@auth)
        @sunstone_test.login

        @dashboard = Sunstone::Dashboard.new(@sunstone_test)

        sunstone_server_conf = @dashboard.get_sunstone_server_conf()
        @thresholds = {
            min: sunstone_server_conf[:threshold_min].to_i,
            low: sunstone_server_conf[:threshold_low].to_i,
            high: sunstone_server_conf[:threshold_high].to_i
        }

        @isEE = false

        if @main_defaults && @main_defaults[:build_components]
            @isEE = @main_defaults[:build_components].include?('enterprise')
        end
    end

    before(:each) do
        sleep 1
    end

    after(:all) do
        @sunstone_test.sign_out
    end

    it "should check allocated CPU thresholds" do
        id = "allocated_cpu"
        values = @dashboard.check_meter_threshold_values(id)

        expect(values[:min]).to eql @thresholds[:min]
        expect(values[:low]).to eql @thresholds[:low]
        expect(values[:high]).to eql @thresholds[:high]
    end

    it "should check allocated mem thresholds" do
        id = "allocated_mem"
        values = @dashboard.check_meter_threshold_values(id)

        expect(values[:min]).to eql @thresholds[:min]
        expect(values[:low]).to eql @thresholds[:low]
        expect(values[:high]).to eql @thresholds[:high]
    end

    it "should verify OpenNebula Enterprise Edition text" do
        xpath = '//*[@id="enterprise_edition"]'
        text = @sunstone_test.get_element_by_xpath(xpath)
        if !@isEE
            # If it is not Enterprise Edition the text shouldn't be there.
            # It has to be false because when get_element_by_xpath() don't
            # find the object it return false instead nil
            expect(text).to eql false
        else
            # If it is Enterprise Edition the text should be there.
            expect(text).not_to eql nil
        end
    end

end