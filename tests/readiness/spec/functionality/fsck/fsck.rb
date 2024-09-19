RSpec.shared_examples_for 'fsck' do |database, errors, unrepaired_errors|
    it 'should run fsck with no errors' do
        run_fsck(0, false)
    end

    context 'only for EE, sqlite DB' do
        before(:all) do
            if @main_defaults && @main_defaults[:build_components]
                @ee = @main_defaults[:build_components].include?('enterprise')
            else
                @ee = false
            end

            if @main_defaults && @main_defaults[:db]
                @sqlite = @main_defaults[:db]['BACKEND'] == 'sqlite'
            end

            skip 'only for sqlite' unless @sqlite
            skip 'only for EE' unless @ee
        end

        it 'should copy the broken DB' do
            @one_test.stop_one

            file = "#{Dir.getwd}/spec/functionality/fsck/databases/#{database}"

            system("cp #{file} #{ONE_DB_LOCATION}/one.db")
        end

        it 'should upgrade the DB' do
            expect(@one_test.upgrade_db).to be(true)
        end

        it 'should dry run fsck' do
            run_fsck(errors, false, true)
        end

        it 'should run fsck and fix errors' do
            run_fsck(errors, false)
        end

        it "should run fsck with #{unrepaired_errors > 0 ? 'unrepaired errors' :
                'no errors'}" do
            run_fsck(unrepaired_errors, false)
        end
    end
end
