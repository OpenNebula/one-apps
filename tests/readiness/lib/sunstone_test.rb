require 'rubygems'
require 'selenium-webdriver'
require 'rspec'
require 'headless'

class SunstoneTest

    def initialize(auth, block_gh = true)
        manage_gh_access(block_gh)
        rescue_debug
        rescue_mem_debug

        retry_loop(
            retries: 10,
            delay_after_retry: 60 # 1 minute
        ) do
            begin
                if Gem.loaded_specs['selenium-webdriver'].version < Gem::Version.create('3.0')
                    $driver = Selenium::WebDriver.for(
                        :chrome,
                        :switches => %w[--headless --disable-gpu --window-size=1920,1080 --no-sandbox]
                    )
                else
                    options = Selenium::WebDriver::Chrome::Options.new
                    if options.respond_to?(:headless)
                        options.headless!
                    else
                        options.add_argument('--headless') 
                    end
                    options.add_argument('window-size=1920,1080')
                    options.add_argument('no-sandbox')
                    options.add_argument('disable-dev-shm-usage')
                    $driver = Selenium::WebDriver.for :chrome, :options => options
                    Selenium::WebDriver.logger.level = :debug
                    Selenium::WebDriver.logger.output = '/tmp/chromedriver.log'
                end
            rescue Net::ReadTimeout => e
                STDERR.puts "Net::ReadTimeout: #{e}"
                rescue_mem_debug('memory_fails.log')
                raise e
            end
        end

        @auth = auth
        wait_loop(:success => true) {
            condition = true
            begin
                $driver.get get_sunstone_url
            rescue
                condition = false
            end
            return condition
        }
    end

    # respect alternative Sunstone URL if specified
    # in the microenv's defaults.yaml
    def get_sunstone_url
        url = RSpec.configuration.main_defaults[:sunstone_url]
    rescue StandardError => e
        STDERR.puts "ERROR sunstone url: #{e}"
    ensure
        url ||= 'http://localhost:9869'

        return url
    end

    # puts dummy entry into static hosts for GitHub so tha
    # Sunstone doesn't stress the real GitHub
    def manage_gh_access(state = false)
        hosts = File.open('/etc/hosts').read
        entry = '127.0.0.1 api.github.com'

        if state && !hosts.include?(entry)
            STDERR.puts '==> Blocking GitHub API'

            open('/etc/hosts', 'a') do |f|
                f.puts unless hosts.end_with?("\n")
                f.puts entry
            end
        elsif !state && hosts.include?(entry)
            STDERR.puts '==> Unblocking GitHub API'

            open('/etc/hosts', 'w') do |f|
                f.puts hosts.gsub("#{entry}\n", '')
            end
        end
    rescue StandardError => e
        STDERR.puts "ERROR: #{e}"
    end

    def rescue_debug
        sunstone_log_file = "#{Tempfile.new('sunstone').path}.log"
        puts "Copying sunstone.log to #{sunstone_log_file} ..."
        copy_file("/var/log/one/sunstone.log", sunstone_log_file)

        sunstone_error_file = "#{Tempfile.new('sunstone').path}.error"
        puts "Copying sunstone.error to #{sunstone_error_file} ..."
        copy_file("/var/log/one/sunstone.error", sunstone_error_file)

        ps_file = "#{Tempfile.new('ps').path}.log"
        puts "Copying ps to #{ps_file} ..."
        system("ps auxwww >> #{ps_file}")
    end

    def rescue_mem_debug(name_file = 'memory.log')
        mem_file = "/var/lib/one/#{name_file}"
        puts "Copying 'free -h' to #{mem_file} ..."
        system("free -h >> #{mem_file}")
    end

    def unmount_driver
        $driver.close
        $driver.quit
        system("kill -9 $(pgrep chrom)")
        manage_gh_access
    end

    def login(auth = @auth)
        Selenium::WebDriver::Wait.new(:timeout => 60, :interval => 1).until {
            begin $driver.find_element(:id, "logo_sunstone")
            rescue Selenium::WebDriver::Error::NoSuchElementError
                $driver.navigate.refresh
            rescue Net::ReadTimeout
            end
        }

        begin
            retry_loop(screenshot: 'error-waiting-login') do
                username = self.get_element_by_id("username")
                username.clear
                username.send_keys auth[:username]

                password = self.get_element_by_id("password")
                password.clear
                password.send_keys auth[:password]

                $driver.find_element(:id, "login_btn").click

                # waiting gui is loaded
                self.get_element_by_class('opennebula-img')
            end
        rescue StandardError => e
            self.unmount_driver
        end

    end

    def sign_out(close_browser = true)
        sleep 1
        self.get_element_by_id("userselector").click
        $driver.find_element(:class, "logout").click

        begin
            Selenium::WebDriver::Wait.new(:timeout => 60).until {
                element = $driver.find_element(:id, "logo_sunstone")
            }
        rescue Selenium::WebDriver::Error::TimeoutError => e
            logo_screenshot = "#{Tempfile.new('logo-sunstone').path}.png"
            STDERR.puts "ERROR: #{e}"
            STDERR.puts "Saving screenshot to #{logo_screenshot} ..."
            $driver.save_screenshot(logo_screenshot)
        end

        self.unmount_driver if close_browser
    end

    def js_errors?
        js_console_log = $driver.manage.logs.get("browser")
        messages = []
        js_console_log.each { |item|
            if item.level == "SEVERE" and !item.message.include? "Unauthorized"
                messages << item.message
            end
        }
        if messages.length > 0
            messages.each { |message|
                fail "js console error: '#{message}'" if message.length > 0
            }
            true
        else
            false
        end
    end

    def core_logs
        wait = Selenium::WebDriver::Wait.new(:timeout => 60)

        wait.until {
           $driver.find_element(:id, "jGrowl")
        }
        element = $driver.find_element(:id, "jGrowl")
        element.find_element(:class, "create_dialog_button").click if element.displayed?
    end

    def get_element_by_id(id)
        wait = Selenium::WebDriver::Wait.new(:timeout => 60)
        sleep 0.2
        element = false
        wait.until {
            begin
                element = $driver.find_element(:id, id)
                element.displayed?
            rescue Selenium::WebDriver::Error::StaleElementReferenceError
            end
        }
        return element
    end

    def get_element_by_class(class_name)
        wait = Selenium::WebDriver::Wait.new(:timeout => 60)
        sleep 0.2
        element = false
        wait.until {
            begin
                element = $driver.find_element(:class, class_name)
                element.displayed?
            rescue Selenium::WebDriver::Error::StaleElementReferenceError
            end
        }
        return element
    end

    def get_element_by_css(css_selector)
      wait = Selenium::WebDriver::Wait.new(:timeout => 60)
      sleep 0.2
      element = false
      wait.until {
          begin
              element = $driver.find_element(:css, css_selector)
              element.displayed?
          rescue Selenium::WebDriver::Error::StaleElementReferenceError
          end
      }
      return element
    end

    def get_element_by_name(name)
        wait = Selenium::WebDriver::Wait.new(:timeout => 60)
        wait.until {
            element = $driver.find_element(:name, name)
            return element if element.displayed?
        }
    end

    def get_element_by_xpath(xpath, screenshot = false)
        begin
            Selenium::WebDriver::Wait.new(:timeout => 10).until {
                element = $driver.find_element(:xpath, xpath)
                element.displayed? ? element : false
            }
        rescue
            if screenshot
                path_file = Tempfile.new("xpath-").path
                $driver.save_screenshot("#{path_file}.png")
            end
            false
        end
    end

    def click_option(dropdown, attr, value)
        fail "Dropdown should be a WebDriver Element" if !dropdown.is_a?(Selenium::WebDriver::Element)
        options = dropdown.find_elements(tag_name: "option")
        options.each { |option| option.click if option.attribute("#{attr}") == "#{value}" }
    end

    def click_option_by_text(dropdown, value)
        fail "Dropdown should be a WebDriver Element" if !dropdown.is_a?(Selenium::WebDriver::Element)
        options = dropdown.find_elements(tag_name: "option")
        options.each { |option| option.click if option.text() == "#{value}" }
    end

    def refresh_resources(resource)
        element = get_element_by_id("#{resource}-tabrefresh_buttons")
        element.click
    end

    def wait_resource_loop(options={}, &block)
        args = { :timeout => 120, :fail_msg => "timeout" }.merge!(options)

        time_start = Time.now

        while (Time.now - time_start < args[:timeout])
            block.call
            sleep 1
        end

        fail "Error: " + args[:fail_msg].to_s
    end

    def wait_resource_create(resource, name, timeout = 60)
        wait_resource_loop(:timeout => timeout, :fail_msg => "create #{resource} (#{name})") {
            status = SafeExec.run("one#{resource} show '#{name}'").status
            break if status == 0
        }
    end

    def wait_resource_update(resource, name, change, timeout = 60)
        wait_resource_loop(:timeout => timeout, :fail_msg => "update #{resource} (#{name})") {
            stdout = SafeExec.run("one#{resource} show -x '#{name}'").stdout
            match = stdout.match(/^<(\w+)>/)
            root_element = match[1]

            xml = XMLElement.new
            xml.initialize_xml(stdout, root_element)

            break if xml[change[:key]] == change[:value]
        }
    end

    # This method does not work for VM resource.
    # If resource is equal to VM please use wait_vm_delete
    def wait_resource_delete(resource, name)
        wait_resource_loop(:timeout => 60, :fail_msg => "delete #{resource} (#{name})") {
            status = SafeExec.run("one#{resource} show '#{name}'").status
            break if status == 255
        }
    end

    def wait_vm_delete(id)
        vm = VM.new(id)
        vm.info
        vm.done?
    end

    def copy_file(source, dest)
        system("cp -r #{source} #{dest}")
    end

    def retry_loop(exceptions: [StandardError],
                   retries: 3,
                   delay_after_retry: 5,
                   screenshot: nil,
                   &block)
        retry_count = 0

        begin
            block.call
        rescue *exceptions => exc
            retry_count += 1
            puts "Failed: #{exc},
                  retry #{retry_count}/#{retries},
                  sleep: #{delay_after_retry}"

            sleep delay_after_retry

            retry if retry_count < retries

            if screenshot
                tempfile = "#{Tempfile.new(screenshot).path}.png"
                $driver.save_screenshot(tempfile)
                fail "ERROR: #{exc}. Screenshot: #{tempfile}"
            end
        end
    end

end
