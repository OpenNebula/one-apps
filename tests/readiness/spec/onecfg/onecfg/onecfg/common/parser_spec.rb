HINTINGPARSER_TESTS = {

    # Basic cases
    %q(set :tmpdir /var/tmp/sunstone)       => { :command => 'set', :path => ':tmpdir', :value => '/var/tmp/sunstone'},
    %q(  set  :tmpdir  /var/tmp/sunstone  ) => { :command => 'set', :path => ':tmpdir', :value => '/var/tmp/sunstone'},
    %q(set :tmpdir "/var/tmp/sunstone")     => { :command => 'set', :path => ':tmpdir', :value => '"/var/tmp/sunstone"'},
    %q(set :tmpdir '/var/tmp/sunstone')     => { :command => 'set', :path => ':tmpdir', :value => "'/var/tmp/sunstone'"},
    %q(set :tmpdir /var/tmp/sunstone)       => { :command => 'set', :path => ':tmpdir', :value => '/var/tmp/sunstone'},
    %q(set :tmpdir "\"/var/tmp/sunstone\"") => { :command => 'set', :path => ':tmpdir', :value => %q("\"/var/tmp/sunstone\"")},
    %q(set :tmpdir "'/var/tmp/sunstone'")   => { :command => 'set', :path => ':tmpdir', :value => %q("'/var/tmp/sunstone'")},
    %q(set :tmpdir '\"/var/tmp/sunstone\"') => { :command => 'set', :path => ':tmpdir', :value => %q('\"/var/tmp/sunstone\"')},
    %q(set :tmpdir '"/var/tmp/sunstone"')   => { :command => 'set', :path => ':tmpdir', :value => %q('"/var/tmp/sunstone"')},

    # Path with spaces
    %q(set "/path with spaces/:tmpdir" "/var/tmp/sunstone")  => { :command => 'set', :path => '/path with spaces/:tmpdir', :value => '"/var/tmp/sunstone"'},
    %q(set "/path with spaces/:tmpdir" '/var/tmp/sunstone')  => { :command => 'set', :path => '/path with spaces/:tmpdir', :value => "'/var/tmp/sunstone'"},
    %q(set '/path with spaces/:tmpdir' '/var/tmp/sunstone')  => { :command => 'set', :path => "'/path",                    :value => "with spaces/:tmpdir' '/var/tmp/sunstone'"},
    %q(set /path with spaces/:tmpdir /var/tmp/sunstone)      => { :command => 'set', :path => '/path',                     :value => 'with spaces/:tmpdir /var/tmp/sunstone'}, # Not supported without quotes (examples above)

    # Path with custom key
    %q(set "/path/\"with_custom_key\"/:tmpdir" "/var/tmp/sunstone")            => { :command => 'set', :path => '/path/"with_custom_key"/:tmpdir',           :value => '"/var/tmp/sunstone"'},
    %q(set "/path/\"with customkey and spaces\"/:tmpdir" "/var/tmp/sunstone")  => { :command => 'set', :path => '/path/"with customkey and spaces"/:tmpdir', :value => '"/var/tmp/sunstone"'},
    %q(set '/path/\"with_custom_key\"/:tmpdir' "/var/tmp/sunstone")            => { :command => 'set', :path => %q('/path/\"with_custom_key\"/:tmpdir'),     :value => '"/var/tmp/sunstone"'},
    %q(set '/path/\"with customkey and spaces\"/:tmpdir' "/var/tmp/sunstone")  => { :command => 'set', :path => %q('/path/\"with),                           :value => %q(customkey and spaces\"/:tmpdir' "/var/tmp/sunstone")},
    %q(set "/path/'with_custom_key'/:tmpdir" "/var/tmp/sunstone")              => { :command => 'set', :path => "/path/'with_custom_key'/:tmpdir",           :value => '"/var/tmp/sunstone"'},
    %q(set "/path/'with customkey and spaces'/:tmpdir" "/var/tmp/sunstone")    => { :command => 'set', :path => "/path/'with customkey and spaces'/:tmpdir", :value => '"/var/tmp/sunstone"'},
    %q(set /path/"with_custom_key"/:tmpdir "/var/tmp/sunstone")                => { :command => 'set', :path => '/path/"with_custom_key"/:tmpdir',           :value => '"/var/tmp/sunstone"'},
    %q(set /path/"with customkey and spaces"/:tmpdir "/var/tmp/sunstone")      => { :command => 'set', :path => '/path/"with',                               :value => 'customkey and spaces"/:tmpdir "/var/tmp/sunstone"'}, # Not supported without quotes (examples above)

    # Value with spaces
    %q(set tmpdir "/var/tmp/sunstone with spaces")     => { :command => 'set', :path => 'tmpdir', :value => '"/var/tmp/sunstone with spaces"'},
    %q(set tmpdir '/var/tmp/sunstone with spaces')     => { :command => 'set', :path => 'tmpdir', :value => "'/var/tmp/sunstone with spaces'"},
    %q(set tmpdir /var/tmp/sunstone with spaces)       => { :command => 'set', :path => 'tmpdir', :value => '/var/tmp/sunstone with spaces'}, # Not supported without quotes (examples above)
    %q(set tmpdir "\"/var/tmp/sunstone with spaces\"") => { :command => 'set', :path => 'tmpdir', :value => %q("\"/var/tmp/sunstone with spaces\"")},
    %q(set tmpdir "\'/var/tmp/sunstone with spaces\'") => { :command => 'set', :path => 'tmpdir', :value => %q("\'/var/tmp/sunstone with spaces\'")},
    %q(set tmpdir '\"/var/tmp/sunstone with spaces\"') => { :command => 'set', :path => 'tmpdir', :value => %q('\"/var/tmp/sunstone with spaces\"')},
    %q(set tmpdir '\'/var/tmp/sunstone with spaces\'') => { :command => 'set', :path => 'tmpdir', :value => %q('\'/var/tmp/sunstone with spaces\'')},
=begin
    # Simple cases with extra
    %q(set :tmpdir value extra)       => ['set', ':tmpdir', 'value', 'extra'],
    %q(set :tmpdir value "extra")     => ['set', ':tmpdir', 'value', 'extra'],
    %q(set :tmpdir value 'extra')     => ['set', ':tmpdir', 'value', 'extra'],
    %q(set :tmpdir value "\"extra\"") => ['set', ':tmpdir', 'value', %q("extra")],
    %q(set :tmpdir value "\'extra\'") => ['set', ':tmpdir', 'value', %q(\'extra\')],
    %q(set :tmpdir value '\"extra\"') => ['set', ':tmpdir', 'value', %q(\"extra\")],
    %q(set :tmpdir value '\'extra\'') => ['set', ':tmpdir', 'value', %q('extra')],

    # Value with spaces + extra
    %q(set :tmpdir "value with spaces" "extra")         => ['set', ':tmpdir', 'value with spaces', 'extra'],
    %q(set :tmpdir 'value with spaces' 'extra')         => ['set', ':tmpdir', 'value with spaces', 'extra'],
    %q(set :tmpdir value with spaces extra)             => ['set', ':tmpdir', 'value', 'with', 'spaces', 'extra'], # Not supported without quotes (examples above)
    %q(set :tmpdir "\"value with spaces\"" "\"extra\"") => ['set', ':tmpdir', %q("value with spaces"), '"extra"'],
    %q(set :tmpdir "'value with spaces'" "'extra'")     => ['set', ':tmpdir', %q('value with spaces'), %q('extra')],
    %q(set :tmpdir "\'value with spaces\'" "'extra'")   => ['set', ':tmpdir', %q(\'value with spaces\'), %q('extra')],

    # Extra with spaces
    %q(set :tmpdir value "extra with spaces")     => ['set', ':tmpdir', 'value', 'extra with spaces'],
    %q(set :tmpdir value 'extra with spaces')     => ['set', ':tmpdir', 'value', 'extra with spaces'],
    %q(set :tmpdir value extra with spaces)       => ['set', ':tmpdir', 'value', 'extra', 'with', 'spaces'], # It would work by using Parser.get_until_end
    %q(set :tmpdir value ""extra with spaces"")   => [], #TODO - how this should work?
    %q(set :tmpdir value ''extra with spaces'')   => [], #TODO - how this should work?
    %q(set :tmpdir value "\"extra with spaces\"") => ['set', ':tmpdir', 'value', %q("extra with spaces")],
    %q(set :tmpdir value "'extra with spaces'")   => ['set', ':tmpdir', 'value', %q('extra with spaces')],
    %q(set :tmpdir value "\'extra with spaces\'") => ['set', ':tmpdir', 'value', %q(\'extra with spaces\')],
    %q(set :tmpdir value '\'extra with spaces\'') => ['set', ':tmpdir', 'value', %q('extra with spaces')],
    %q(set :tmpdir value '"extra with spaces"")   => ['set', ':tmpdir', 'value', %q("extra with spaces")],
    %q(set :tmpdir value '\"extra with spaces\"") => ['set', ':tmpdir', 'value', %q(\"extra with spaces\")],

    # Value + extra with spaces at both
    %q(set :tmpdir "value with spaces" "extra with spaces")         => ['set', ':tmpdir', 'value with spaces', 'extra with spaces'],
    %q(set :tmpdir 'value with spaces' 'extra with spaces')         => ['set', ':tmpdir', 'value with spaces', 'extra with spaces'],
    %q(set :tmpdir value with spaces extra with spaces)             => ['set', ':tmpdir', 'value', 'with', 'spaces', 'extra', 'with', 'spaces'], # Not supported without quotes (examples above)
    %q(set :tmpdir "\"value with spaces\"" "\"extra with spaces\"") => ['set', ':tmpdir', %q("value with spaces"), %q("extra with spaces")],
    %q(set :tmpdir "'value with spaces'" "'extra with spaces'")     => ['set', ':tmpdir', %q('value with spaces'), %q('extra with spaces')],
    %q(set :tmpdir "\'value with spaces\'" "\'extra with spaces\'") => ['set', ':tmpdir', %q(\'value with spaces\'), %q(\'extra with spaces\')],
    %q(set :tmpdir '\"value with spaces\"' '\"extra with spaces\"') => ['set', ':tmpdir', %q(\"value with spaces\"), %q(\"extra with spaces\")],
    %q(set :tmpdir '"value with spaces"' '"extra with spaces"')     => ['set', ':tmpdir', %q("value with spaces"), %q("extra with spaces")],
    %q(set :tmpdir '\'value with spaces\'' '\'extra with spaces\'') => ['set', ':tmpdir', %q('value with spaces'), %q('extra with spaces')],
=end
}

RSpec.describe 'OneCfg::Common::HintingParser' do
    HINTINGPARSER_TESTS.each do |input, output|
        it "parses - #{input}" do
            parser = OneCfg::Common::HintingParser.new(input)

            expect(parser.parse(false)).to eq(output)
        end
    end
=begin
    it "parses with read_until_end" do
        input = 'set :tmpdir value extra with spaces'

        parser = OneCfg::Common::HintingParser.new(input)

        expect(parser.get_word).to eq('set')
        expect(parser.get_word).to eq(':tmpdir')
        expect(parser.get_word).to eq('value')
        expect(parser.get_until_end).to eq('extra with spaces')
    end
=end
end
