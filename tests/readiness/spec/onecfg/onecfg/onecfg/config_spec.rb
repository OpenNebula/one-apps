require 'rspec'

CFG_EX_MOD = OneCfg::Config::Exception

RSpec.describe 'Class OneCfg::Exception::Generic' do
    it_behaves_like 'exception', OneCfg::Exception::Generic, 'msg'
end

RSpec.describe 'Class OneCfg::Exception::FileNotFound' do
    it_behaves_like 'exception', OneCfg::Exception::FileNotFound
end

RSpec.describe 'Class OneCfg::Exception::FileReadeError' do
    it_behaves_like 'exception',
                    OneCfg::Exception::FileReadError,
                    'msg',
                    true
end

RSpec.describe 'Class OneCfg::Exception::FileWriteError' do
    it_behaves_like 'exception',
                    OneCfg::Exception::FileWriteError,
                    'msg',
                    true
end

RSpec.describe "Class #{CFG_EX_MOD}::FatalError" do
    it_behaves_like 'exception', CFG_EX_MOD::FatalError, 'msg', true
end

RSpec.describe "Class #{CFG_EX_MOD}::UnsupportedVersion" do
    it_behaves_like 'exception', CFG_EX_MOD::UnsupportedVersion, 'msg', true
end

RSpec.describe "Class #{CFG_EX_MOD}::StructureError" do
    it_behaves_like 'exception', CFG_EX_MOD::StructureError, 'msg', true
end

RSpec.describe "Class #{CFG_EX_MOD}::NoContent" do
    it_behaves_like 'exception', CFG_EX_MOD::NoContent
end

RSpec.describe "Class #{CFG_EX_MOD}::PatchException" do
    it_behaves_like 'exception', CFG_EX_MOD::PatchException, 'msg', true
end

RSpec.describe "Class #{CFG_EX_MOD}::PatchPathNotFound" do
    it_behaves_like 'exception', CFG_EX_MOD::PatchException, [], true
end

RSpec.describe "Class #{CFG_EX_MOD}::PatchValueNotFound" do
    it_behaves_like 'exception', CFG_EX_MOD::PatchValueNotFound, [], true
end

RSpec.describe "Class #{CFG_EX_MOD}::PatchInvalidMultiple" do
    it_behaves_like 'exception', CFG_EX_MOD::PatchInvalidMultiple, [], true
end

RSpec.describe "Class #{CFG_EX_MOD}::PatchUnexpectedData" do
    it_behaves_like 'exception', CFG_EX_MOD::PatchUnexpectedData, [], true
end

RSpec.describe "Class #{CFG_EX_MOD}::PatchExpectedHash" do
    it_behaves_like 'exception', CFG_EX_MOD::PatchExpectedHash, [], true
end

RSpec.describe "Class #{CFG_EX_MOD}::PatchExpectedArray" do
    it_behaves_like 'exception', CFG_EX_MOD::PatchExpectedArray, [], true
end

RSpec.describe "Class #{CFG_EX_MOD}::PatchRetryOperation" do
    it_behaves_like 'exception', CFG_EX_MOD::PatchRetryOperation
end
