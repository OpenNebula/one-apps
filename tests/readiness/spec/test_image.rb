require 'init'
require 'lib/image'

RSpec.describe 'Image lib testing' do
    before(:all) do
        @defaults = RSpec.configuration.defaults
        @info = {}
    end

    it 'loads image 0' do
        img = CLIImage.create('ass', 1, '--path http://services/images/lxd.qcow2')

        pp img.ready?
        pp img.name
        pp img.source
        pp img.size
        pp img.format
        pp img.type
        pp img.backup?
        pp img.persistent?

        img.delete

        # img = Image.new(3)
        # ids = img.restore
    end
end
