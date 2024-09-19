require 'sunstone/Utils'

class Sunstone
    class Marketplace
        def initialize(sunstone_test)
            @general_tag = "storage"
            @resource_tag = "marketplaces"
            @datatable = "dataTableMarketplaces"
            @sunstone_test = sunstone_test
            @utils = Utils.new(sunstone_test)
            @wait = Selenium::WebDriver::Wait.new(:timeout => 10)
        end

        def create(name, hash = []) #hash -> market_mad, description, 
            @utils.navigate(@general_tag, @resource_tag)

            if !@utils.check_exists(2, name, @datatable)
                @utils.navigate_create(@general_tag, @resource_tag)

                @sunstone_test.get_element_by_id("NAME").send_keys "#{name}"

                if hash[:description]
                    @sunstone_test.get_element_by_id("DESCRIPTION").send_keys "#{hash[:description]}"
                end

                if hash[:market_mad]
                    dropdown = @sunstone_test.get_element_by_id("MARKET_MAD")
                    @sunstone_test.click_option(dropdown, "value", hash[:market_mad])
                end

                if hash[:endpoint]
                    if hash[:market_mad] == "one"
                        @sunstone_test.get_element_by_id("ENDPOINTONE").send_keys "#{hash[:endpoint]}"
                    elsif hash[:market_mad] == "s3"
                        @sunstone_test.get_element_by_id("ENDPOINTS3").send_keys "#{hash[:endpoint]}"
                    elsif hash[:market_mad] == "linuxcontainers"
                        @sunstone_test.get_element_by_id("ENDPOINTLXD").send_keys "#{hash[:endpoint]}"
                    end
                end

                # For HTTP Server
                if hash[:base_url]
                    @sunstone_test.get_element_by_id("BASE_URL").send_keys "#{hash[:base_url]}"
                end

                if hash[:public_dir]
                    @sunstone_test.get_element_by_id("PUBLIC_DIR").send_keys "#{hash[:public_dir]}"
                end

                if hash[:brige_list]
                    @sunstone_test.get_element_by_id("BRIDGE_LIST").send_keys "#{hash[:brige_list]}"
                end

                # For Amazon S3
                if hash[:access_key]
                    @sunstone_test.get_element_by_id("ACCESS_KEY_ID").send_keys "#{hash[:access_key]}"
                end

                if hash[:secret_key]
                    @sunstone_test.get_element_by_id("SECRET_ACCESS_KEY").send_keys "#{hash[:secret_key]}"
                end

                if hash[:bucket]
                    @sunstone_test.get_element_by_id("BUCKET").send_keys "#{hash[:bucket]}"
                end

                if hash[:region]
                    @sunstone_test.get_element_by_id("REGION").send_keys "#{hash[:region]}"
                end
                
                if hash[:total_mb]
                    @sunstone_test.get_element_by_id("TOTAL_MB").send_keys "#{hash[:total_mb]}"
                end

                if hash[:signature_version]
                    @sunstone_test.get_element_by_id("SIGNATURE_VERSION").send_keys "#{hash[:signature_version]}"
                end

                if hash[:force_path_style]
                    @sunstone_test.get_element_by_id("FORCE_PATH_STYLE").send_keys "#{hash[:force_path_style]}"
                end

                if hash[:read_length]
                    @sunstone_test.get_element_by_id("READ_LENGTH").send_keys "#{hash[:read_length]}"
                end

                # For Linux containers
                if hash[:image_size_mb]
                    @sunstone_test.get_element_by_id("IMAGE_SIZE_MB").send_keys "#{hash[:image_size_mb]}"
                end

                if hash[:filesystem]
                    @sunstone_test.get_element_by_id("FILESYSTEM").send_keys "#{hash[:filesystem]}"
                end

                if hash[:format]
                    @sunstone_test.get_element_by_id("FORMAT").send_keys "#{hash[:format]}"
                end

                if hash[:skip_untested]
                    @sunstone_test.get_element_by_id("SKIP_UNTESTED").send_keys "#{hash[:skip_untested]}"
                end

                @utils.submit_create(@resource_tag)
            end
        end

        def create_advanced(template)
            @utils.create_advanced(template, @general_tag, @resource_tag, "MarketPlace")
        end

        def delete(name)
            @utils.delete_resource(name, @general_tag, @resource_tag, @datatable)
        end
    end
end
