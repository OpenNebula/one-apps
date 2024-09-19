require 'init_functionality'
require 'flow_helper'

require 'tempfile'

# Check registration time of clone template changes
#
# @param id1 [Integer] Template ID 1
# @param id2 [Integer] Template ID 2
def check_registration_time(id1, id2)
    t1 = cli_action_json("oneflow-template show #{id1} -j ")
    t2 = cli_action_json("oneflow-template show #{id2} -j ")

    t1 = t1['DOCUMENT']['TEMPLATE']['BODY']['registration_time']
    t2 = t2['DOCUMENT']['TEMPLATE']['BODY']['registration_time']

    expect(t1).not_to eq(t2)
end

RSpec.describe 'OneFlow Template' do
    include FlowHelper

    prepend_before(:all) do
        @defaults_yaml = File.join(File.dirname(__FILE__), 'defaults.yaml')
    end

    before(:all) do
        start_flow

        cli_action('oneimage create -d default --name test_flow --size 1')

        wait_loop do
            image = cli_action_xml('oneimage show test_flow -x')

            break if image['STATE'] == '1'
        end

        # Create VM template
        template = vm_template(true)

        template_file = Tempfile.new('vm_template')
        template_file << template
        template_file.close

        cli_action("onetemplate create #{template_file.path}")

        # Create Service template
        template = service_template('none')
        @template_id = cli_create_stdin('oneflow-template create', template)
        @templates   = []
    end

    it 'clone template' do
        # Add some wait to avoid same registration time
        sleep 5

        t_id = cli_create("oneflow-template clone #{@template_id} NONE")

        expect(cli_action_json("oneflow-template show #{t_id} -j ")).not_to be_nil
        cli_action('onetemplate show TEST-NONE', false)
        cli_action('oneimage show vm_template-NONE-disk-0', false)

        @templates << t_id

        check_registration_time(@template_id, t_id)
    end

    it 'clone template recursively with just template' do
        t_id = cli_create("oneflow-template clone #{@template_id} TEMP --recursive-templates")

        expect(cli_action_json("oneflow-template show #{t_id} -j ")).not_to be_nil
        expect(cli_action_xml('onetemplate show vm_template-TEMP -x')).not_to be_nil
        cli_action('oneimage show vm_template-TEMP-disk-0', false)

        @templates << t_id

        check_registration_time(@template_id, t_id)
    end

    it 'clone template recursively with all' do
        t_id = cli_create("oneflow-template clone #{@template_id} ALL -r")

        expect(cli_action_json("oneflow-template show #{t_id} -j ")).not_to be_nil
        expect(cli_action_xml('onetemplate show vm_template-ALL -x')).not_to be_nil
        expect(cli_action_xml('oneimage show vm_template-ALL-disk-0 -x')).not_to be_nil

        @templates << t_id

        check_registration_time(@template_id, t_id)
    end

    it 'delete NONE' do
        templates = cli_action('onetemplate list --csv -l ID --no-header').stdout
        templates = templates.split("\n").size
        images    = cli_action('oneimage list --csv -l ID --no-header').stdout
        images    = images.split("\n").size

        cli_action("oneflow-template delete #{@templates.shift}")

        c_templates = cli_action('onetemplate list --csv -l ID --no-header').stdout
        c_templates = c_templates.split("\n").size
        c_images    = cli_action('oneimage list --csv -l ID --no-header').stdout
        c_images    = c_images.split("\n").size

        expect(templates).to eq(c_templates)
        expect(images).to eq(c_images)
    end

    it 'delete TEMPLATES' do
        templates = cli_action('onetemplate list --csv -l ID --no-header').stdout
        templates = templates.split("\n").size
        images    = cli_action('oneimage list --csv -l ID --no-header').stdout
        images    = images.split("\n").size

        cli_action("oneflow-template delete #{@templates.shift} --delete-vm-templates")

        c_templates = cli_action('onetemplate list --csv -l ID --no-header').stdout
        c_templates = c_templates.split("\n").size
        c_images    = cli_action('oneimage list --csv -l ID --no-header').stdout
        c_images    = c_images.split("\n").size

        expect(templates).to eq(c_templates + 1)
        expect(images).to eq(c_images)
    end

    it 'delete ALL' do
        templates = cli_action('onetemplate list --csv -l ID --no-header').stdout
        templates = templates.split("\n").size
        images    = cli_action('oneimage list --csv -l ID --no-header').stdout
        images    = images.split("\n").size

        cli_action("oneflow-template delete #{@templates.shift} --delete-images")

        c_templates = cli_action('onetemplate list --csv -l ID --no-header').stdout
        c_templates = c_templates.split("\n").size
        c_images    = cli_action('oneimage list --csv -l ID --no-header --filter STAT=rdy').stdout
        c_images    = c_images.split("\n").size

        expect(templates).to eq(c_templates + 1)
        expect(images).to eq(c_images + 1)
    end

    after(:all) do
        stop_flow
    end

    after(:each) do
        FileUtils.rm_r(Dir['/tmp/opennebula_dummy_actions/*'])
    end
end
