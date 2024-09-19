require 'rspec'
require 'tempfile'

def diff(d1, d2)
    _o, _e, s = Open3.capture3("diff -qr #{d1} #{d2}")

    s.success?
end

def run_transaction(src)
    Dir.mktmpdir do |tmpdir|
        FileUtils.cp_r("#{src}/.", tmpdir)

        tr = OneCfg::Transaction.new
        tr.prefix = tmpdir
        yield(tr, tmpdir)
    end
end

RSpec.describe 'Class OneCfg::Transaction' do
    TR_SRC = one_file_fixture('upgrade/stock_files/5.12.0', 'bin/onecfg')

    it 'runs empty transaction' do
        run_transaction(TR_SRC) do |tr, tmpdir|
            tr.execute do |tr_prefix, fops|
                true
            end

            expect(diff(TR_SRC, tmpdir)).to eq(true)
        end
    end

    it 'runs simple transaction' do
        run_transaction(TR_SRC) do |tr, tmpdir|
            tr.execute do |tr_prefix, fops|
                fops.delete('/etc/one/oned.conf')
            end

            expect(diff(TR_SRC, tmpdir)).to eq(false)
        end
    end

    it 'runs simple transaction with post-copy hook' do
        run_transaction(TR_SRC) do |tr, tmpdir|
            shared_value = 50

            # hook gets return value of transaction
            tr.hook_post_copy = lambda do |code_ret|
                expect(code_ret).to eq(shared_value)
                shared_value += 1
            end

            ret = tr.execute do |tr_prefix, fops|
                fops.delete('/etc/one/oned.conf')

                # returned value is passed to hook
                shared_value
            end

            expect(diff(TR_SRC, tmpdir)).to eq(false)
            expect(ret).to eq(50)
            expect(shared_value).to eq(51)
        end
    end

    it 'rollbacks transaction on exception' do
        run_transaction(TR_SRC) do |tr, tmpdir|
            begin
                tr.execute do |tr_prefix, fops|
                    fops.delete('/etc/one/oned.conf')
                    raise StandardError
                end
            rescue StandardError => e
                expect(diff(TR_SRC, tmpdir)).to eq(true)
            end
        end
    end

    it 'rollbacks transaction on post-copy hook exception' do
        run_transaction(TR_SRC) do |tr, tmpdir|
            begin
                tr.hook_post_copy = lambda do |code_ret|
                    raise StandardError
                end

                tr.execute do |tr_prefix, fops|
                    fops.delete('/etc/one/oned.conf')
                end
            rescue StandardError => e
                expect(diff(TR_SRC, tmpdir)).to eq(true)
            end
        end
    end
end
