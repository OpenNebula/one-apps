#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

RSpec.describe "Nested filters" do
    before(:all) do
        @info = Hash.new
    end

    it "Should get all users" do
        @info[:users_all] = %x[oneuser list]
        expect($?).to eq(0)
    end

    it "Should get oneadmin user" do
        @info[:users_oneadmin] = %x[oneuser list -f NAME=oneadmin]
        expect($?).to eq(0)
    end

    it "Should validate OR operator" do
        @info[:users_or] = %x[oneuser list -f GROUP=oneadmin,MEMORY=- --operator OR]
        expect(@info[:users_or]).to eq(@info[:users_all])
    end

    it "Should validate AND operator" do
        @info[:users_and] = %x[oneuser list -f GROUP=oneadmin,MEMORY=- --operator and]
        expect(@info[:users_and]).to eq(@info[:users_oneadmin])
    end
end
