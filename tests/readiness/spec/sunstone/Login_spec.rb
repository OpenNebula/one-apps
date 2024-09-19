require 'init_functionality'
require 'sunstone_test'

RSpec.describe "Sunstone LogIn", :type => 'skip' do

    before(:all) do
        user = @client.one_auth.split(":")
        @auth = {
            :username => user[0],
            :password => user[1]
        }

        @sunstone_test = SunstoneTest.new(@auth)

        @isEE = false

        if @main_defaults && @main_defaults[:build_components]
            @isEE = @main_defaults[:build_components].include?('enterprise')
        end
    end

    before(:each) do
        sleep 1
    end

    after(:all) do
        # this test dont login
        @sunstone_test.unmount_driver
    end

    it "should verify OpenNebula Enterprise Edition text" do

        Selenium::WebDriver::Wait.new(:timeout => 60, :interval => 1).until {
            begin $driver.find_element(:id, "footer")
            rescue Selenium::WebDriver::Error::NoSuchElementError
                $driver.navigate.refresh
            end
        }

        xpath = '//*[@id="footer"]/a[2]'
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
