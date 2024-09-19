require 'init'
require 'sunstone_test'

RSpec.describe "Zone test", :type => 'skip' do

  before(:all) do
    user = @client.one_auth.split(":")
    @auth = {
      :username => user[0],
      :password => user[1]
    }
    @sunstone_test = SunstoneTest.new(@auth)
    @sunstone_test.login
  end

  before(:each) do
    sleep 6
  end

  after(:all) do
    @sunstone_test.sign_out
  end

  it "Change Zone" do
    begin
      id = ""
      user_zone = @sunstone_test.get_element_by_class("user-zone-info")
      user_zone.find_elements(tag_name: "a").each  do |a|
        next unless a.attribute("id") === "zonelector"
        id = a.find_element(tag_name: "span").attribute("innerHTML").strip!
        a.click
        a.find_element(:xpath, "..").find_elements(tag_name:"a").each do |a2|
          next unless a2.attribute("id") != id && a2.attribute("class") == "zone-choice"
          a2.click
        end
      end
      sleep 2
      user_zone = @sunstone_test.get_element_by_class("user-zone-info")
      user_zone.find_elements(tag_name: "a").each  do |a|
        next unless a.attribute("id") === "zonelector"
        new_zone = a.find_element(tag_name: "span").attribute("innerHTML").strip!
        if(id === new_zone)
          raise "No change zone"
        end
      end
    rescue Exception => e
      raise "No find element to change zone"
    end
  end

end
