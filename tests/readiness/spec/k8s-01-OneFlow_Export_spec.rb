require 'init'

SERVICES_BASE_URL = 'http://services/images/'

K8S_TEMPLATE_DIR = '/opt/marketplace.git/appliances/OneKE_1.29a/'
K8S_SERVICE_NAME = 'Service OneKE 1.29 Airgapped'

# Convert image urls to point to local HTTP server and strip version data
def patch_image_urls
    Dir["#{K8S_TEMPLATE_DIR}/*.yaml"].each do |path|
        payload = YAML.safe_load File.read(path)

        images = payload['images']
        next if images.nil?

        images.map! do |item|
            uri = URI.parse item['url']

            extname = File.extname uri.path
            basename = File.basename uri.path, extname

            if basename.start_with? 'service_'
                basename_no_version = basename.split('-').first
                item['url'] = "#{SERVICES_BASE_URL}#{basename_no_version}#{extname}"
            end

            item
        end

        File.write path, YAML.dump(payload)
    end
end

RSpec.describe 'Export OneKE/OneFlow service from mocked One marketplace' do
    before(:all) do
        patch_image_urls
        cli_action "onemarket disable 'OpenNebula Public'", nil
        cli_action "onemarket enable 'OpenNebula Public'", nil
    end
    it 'export OneKE/OneFlow service' do
        cli_action "onemarketapp export '#{K8S_SERVICE_NAME}' '#{K8S_SERVICE_NAME}' -d 1", nil
    end
end
