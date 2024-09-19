
require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
describe "XSD for xml documents test" do

#---------------------------------------------------------------------------
  # TESTS
  #---------------------------------------------------------------------------
  it "XML Schema" do
        # Copy xsd files from dist location
        Dir.glob('/usr/share/one/schemas/xsd/*.xsd').each do |f|
          FileUtils.cp(f, './spec/functionality/xsd/')
        end

        Dir.chdir("./spec/functionality/xsd") {
            `./test.sh`
            out = File.read("output.log")
            error = ""
            if out.include? "error"
                out.lines.select{|e|
                    if e.include?('error')
                        error = "#{error} #{e}"
                    end
                }
                `rm output.log`
                `rm -r samples`
                fail error
            end
            `rm output.log`
            `rm -r samples`
        }
    end
end
