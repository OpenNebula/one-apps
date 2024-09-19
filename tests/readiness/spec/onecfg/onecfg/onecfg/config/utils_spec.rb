require 'rspec'
require 'hashdiff'
require 'pp'

RSpec.describe 'Class OneCfg::Config::Utils' do
    DEEP_COMPARE_EXAMPLES = [{
        :name       => 'nils',
        :val1       => nil,
        :val2       => nil,
        :ret        => true,
        :ret_strict => true
    }, {
        :name       => 'strings',
        :val1       => 'HelloMyDearFriend',
        :val2       => 'HelloMyDearFriend',
        :ret        => true,
        :ret_strict => true
    }, {
        :name       => 'integers',
        :val1       => 12345,
        :val2       => 12345,
        :ret        => true,
        :ret_strict => true
    }, {
        :name       => 'empty arrays',
        :val1       => [],
        :val2       => [],
        :ret        => true,
        :ret_strict => true
    }, {
        :name       => 'empty hashes',
        :val1       => {},
        :val2       => {},
        :ret        => true,
        :ret_strict => true
    }, {
        :name       => 'different types (1)',
        :val1       => [],
        :val2       => {},
        :ret        => false,
        :ret_strict => false
    }, {
        :name       => 'different types (2)',
        :val1       => {},
        :val2       => nil,
        :ret        => false,
        :ret_strict => false
    }, {
        :name       => 'different types (3)',
        :val1       => '123',
        :val2       => 123,
        :ret        => false,
        :ret_strict => false
    }, {
        :name       => 'different types (4)',
        :val1       => 123,
        :val2       => 123.4,
        :ret        => false,
        :ret_strict => false
    }, {
        :name       => 'different types (5)',
        :val1       => File,
        :val2       => Object.new,
        :ret        => false,
        :ret_strict => false
    }, {
        :name       => 'arrays (1)',
        :val1       => %w[a b c d],
        :val2       => %w[a b c d],
        :ret        => true,
        :ret_strict => true
    }, {
        :name       => 'arrays (2)',
        :val1       => %w[a b c d],
        :val2       => %w[a b c e],
        :ret        => false,
        :ret_strict => false
    }, {
        :name       => 'arrays (3)',
        :val1       => %w[a b c d],
        :val2       => %w[d c b a],
        :ret        => true,
        :ret_strict => false
    }, {
        :name       => 'arrays (4)',
        :val1       => ['a', 'b', 3, 'd'],
        :val2       => ['a', 'b', 3, 'd'],
        :ret        => true,
        :ret_strict => true
    }, {
        :name       => 'arrays (5)',
        :val1       => ['a', 'b', 3, 'd'],
        :val2       => ['a', 'b', '3', 'd'],
        :ret        => false,
        :ret_strict => false
    }, {
        :name       => 'arrays (6)',
        :val1       => ['a', 'b', nil, nil, 'e'],
        :val2       => ['a', 'b', 'e', nil, nil],
        :ret        => true,
        :ret_strict => false
    }, {
        :name       => 'arrays (7)',
        :val1       => ['a', 'b', nil, nil, 'e'],
        :val2       => ['a', 'b', 'e', nil, 'e'],
        :ret        => false,
        :ret_strict => false
    }, {
        :name       => 'nested arrays (1)',
        :val1       => ['a', 'b', ['c'], 'd', 'e'],
        :val2       => ['a', 'b', ['c'], 'd', 'e'],
        :ret        => true,
        :ret_strict => true
    }, {
        :name       => 'nested arrays (2)',
        :val1       => ['a', 'b', ['c'], 'd', 'e'],
        :val2       => ['a', 'b', 'c', 'd', 'e'],
        :ret        => false,
        :ret_strict => false,
    }, {
        :name       => 'nested arrays (3)',
        :val1       => ['a', 'b', ['c'], 'd', 'e'],
        :val2       => ['a', 'b', 'd', ['c'], 'e'],
        :ret        => true,
        :ret_strict => false
    }, {
        :name       => 'nested arrays (4)',
        :val1       => ['a', 'b', ['c'], [[[['d', 'e', 'f']],'g']], 'h'],
        :val2       => ['a', 'b', ['c'], [[[['d', 'e', 'f']],'g']], 'h'],
        :ret        => true,
        :ret_strict => true
    }, {
        :name       => 'nested arrays (5)',
        :val1       => ['a', 'b', ['c'], [[[['d', 'e', 'f']],'g']], 'h'],
        :val2       => ['a', 'b', ['c'], [[[['f', 'e', 'd']],'g']], 'h'],
        :ret        => true,
        :ret_strict => false
    }, {
        :name       => 'nested arrays (6)',
        :val1       => ['a', 'b', ['c'], [[[['d', 'e', 'f']],'g']], 'h'],
        :val2       => ['a', 'b', ['c'], [['g', [['d', 'e', 'f']]]], 'h'],
        :ret        => true,
        :ret_strict => false
    }, {
        :name       => 'nested arrays (7)',
        :val1       => ['a', 'b', ['c'], [[[['d', 'e', 'f']],'g']], 'h'],
        :val2       => [['c'], 'h', [['g', [['f', 'd', 'e']]]], 'a', 'b'],
        :ret        => true,
        :ret_strict => false
    }, {
        :name       => 'nested arrays (8)',
        :val1       => ['a', ['b'], [['c', nil, 123, 'e']]],
        :val2       => ['a', ['b'], [['c', nil, 123, 'e']]],
        :ret        => true,
        :ret_strict => true
    }, {
        :name       => 'nested arrays (9)',
        :val1       => ['a', ['b'], [['c', nil, 123, 'e']]],
        :val2       => ['a', ['b'], [['c', nil, nil, 123, 'e']]],
        :ret        => false,
        :ret_strict => false
    }, {
        :name       => 'nested arrays (10)',
        :val1       => ['a', ['b'], [['c', nil, 123, 'e']]],
        :val2       => ['a', ['b'], [['c', nil, '123', 'e']]],
        :ret        => false,
        :ret_strict => false
    }, {
        :name       => 'nested arrays (11)',
        :val1       => ['a', ['b'], [['c', nil, 123, 'e']]],
        :val2       => ['a', [['c', nil, 123, 'e']], ['b']],
        :ret        => true,
        :ret_strict => false
    }, {
        :name       => 'nested arrays (12)',
        :val1       => ['a', ['b'], [['c', nil, 123, 'e']]],
        :val2       => ['a', [['c', 123, 'e', nil]], ['b']],
        :ret        => true,
        :ret_strict => false
    }, {
        :name       => 'nested arrays (13)',
        :val1       => ['a', ['b'], [['c', nil, 123, 'e']]],
        :val2       => ['a', [['c', 123, 'e', nil]], 'b'],
        :ret        => false,
        :ret_strict => false
    }, {
        :name       => 'nested arrays (14)',
        :val1       => [[['a', 'b', ['c'], 'd', 'e']]],
        :val2       => [[['a', 'b', ['c'], 'd', 'e']]],
        :ret        => true,
        :ret_strict => true
    }, {
        :name       => 'nested arrays (15)',
        :val1       => [[['a', 'b', ['c'], 'd', 'e']]],
        :val2       => [[['a', 'b', 'c', 'd', 'e']]],
        :ret        => false,
        :ret_strict => false
    }, {
        :name       => 'nested arrays (16)',
        :val1       => [[['a', 'b', ['c'], 'd', 'e']]],
        :val2       => [[['a', 'b', 'd', 'e', ['c']]]],
        :ret        => true,
        :ret_strict => false
    }, {
        :name       => 'nested arrays (17)',
        :val1       => [[['a', 'b', ['c'], 'd', 'e']]],
        :val2       => [[[['a', 'b', ['c'], 'd', 'e']]]],
        :ret        => false,
        :ret_strict => false
    }, {
        :name       => 'nested arrays (18)',
        :val1       => [[['a', 'b', ['c'], 'd', 'e']]],
        :val2       => [['a', 'b', ['c'], 'd', 'e']],
        :ret        => false,
        :ret_strict => false
    }, {
        :name       => 'hashes (1)',
        :val1       => { 'k1' => '1', 'k2' => '2' },
        :val2       => { 'k1' => '1', 'k2' => '2' },
        :ret        => true,
        :ret_strict => true
    }, {
        :name       => 'hashes (2)',
        :val1       => { 'k1' => '1', 'k2' => '2' },
        :val2       => { 'k2' => '2', 'k1' => '1' },
        :ret        => true,
        :ret_strict => true
    }, {
        :name       => 'hashes (3)',
        :val1       => { 'k1' => '1', 'k2' => nil },
        :val2       => { 'k1' => '1', 'k2' => nil },
        :ret        => true,
        :ret_strict => true
    }, {
        :name       => 'hashes (4)',
        :val1       => { 'k1' => '1', 'k2' => nil },
        :val2       => { 'k1' => '1' },
        :ret        => false,
        :ret_strict => false
    }, {
        :name       => 'hashes (5)',
        :val1       => { 'k1' => '1', 'k2' => '2' },
        :val2       => { 'k1' => 1, 'k2' => 2 },
        :ret        => false,
        :ret_strict => false
    }, {
        :name       => 'hashes (6)',
        :val1       => { 'k1' => '1', nil => '2', 3 => :symbol, [['key']] => 'val' },
        :val2       => { 'k1' => '1', nil => '2', 3 => :symbol, [['key']] => 'val' },
        :ret        => true,
        :ret_strict => true
    }, {
        :name       => 'hashes (7)',
        :val1       => { 'k1' => '1', nil => '2', 3 => :symbol },
        :val2       => { 'k1' => '1', nil => '3', 3 => :symbol },
        :ret        => false,
        :ret_strict => false
    }, {
        :name       => 'hashes (8)',
        :val1       => { 'k1' => '1', nil => '2', 3 => :symbol },
        :val2       => { 'k1' => '1', nil => '2', 4 => :symbol },
        :ret        => false,
        :ret_strict => false
    }, {
        :name       => 'hashes (9)',
        :val1       => { 'k1' => '1', nil => '2', 3 => :symbol, [['key']] => 'val' },
        :val2       => { 'k1' => '1', nil => '2', 3 => :symbol, 'key' => 'val' },
        :ret        => false,
        :ret_strict => false
    }, {
        :name       => 'hashes (10)',
        :val1       => { 'k1' => '1', nil => '2', 3 => :symbol, [['key']] => 'val' },
        :val2       => { 'k1' => '1', nil => '2', 3 => :symbol, ['key'] => 'val' },
        :ret        => false,
        :ret_strict => false
    }, {
        :name       => 'hashes (11)',
        :val1       => { 'k1' => '1', nil => '2', 3 => :symbol, [['key']] => 'val' },
        :val2       => { 'k1' => '1', nil => '2', 3 => :symbol, [['key']] => 'XXX' },
        :ret        => false,
        :ret_strict => false
    }, {
        :name       => 'nested hashes (1)',
        :val1       => { 'k1' => '1', 'k2' => { 'n1' => { 'n2' => '2' } } },
        :val2       => { 'k1' => '1', 'k2' => { 'n1' => { 'n2' => '2' } } },
        :ret        => true,
        :ret_strict => true
    }, {
        :name       => 'nested hashes (2)',
        :val1       => { 'k1' => '1', 'k2' => { 'n1' => { 'n2' => '2' } } },
        :val2       => { 'k1' => '1', 'k2' => { 'n2' => { 'n1' => '2' } } },
        :ret        => false,
        :ret_strict => false
    }, {
        :name       => 'nested hashes (3)',
        :val1       => { 'k1' => '1', 'k2' => { 'n1' => { 'n2' => '2' } } },
        :val2       => { 'k1' => '1', 'k2' => { 'n1' => [{ 'n2' => '2' }] } },
        :ret        => false,
        :ret_strict => false
    }, {
        :name       => 'nested hashes (4)',
        :val1       => { 'k1' => '1', 'k2' => { 'n1' => { 'n2' => '2' } } },
        :val2       => { 'k1' => { 'n1' => { 'n2' => '2' } }, 'k2' => '1' },
        :ret        => false,
        :ret_strict => false
    }, {
        :name       => 'nested hashes (5)',
        :val1       => { 'k1' => '1', 'k2' => { 'n1' => { 'n2' => '2' } } },
        :val2       => { 'k1' => '1', 'k2' => { 'n1' => { 'n2' => '2' } } },
        :ret        => true,
        :ret_strict => true
    }, {
        :name       => 'nested hashes (6)',
        :val1       => { 'k1' => '1', 'k2' => { :n1 => { nil => '2', 3 => 4 } } },
        :val2       => { 'k1' => '1', 'k2' => { :n1 => { nil => '2', 3 => 4 } } },
        :ret        => true,
        :ret_strict => true
    }, {
        :name       => 'nested hashes (7)',
        :val1       => { 'k1' => '1', 'k2' => { :n1 => { nil => '2', 3 => 4 } } },
        :val2       => { 'k2' => { 'n1'.to_sym => { 3 => 4, nil => '2' } }, 'k1' => '1' },
        :ret        => true,
        :ret_strict => true
    }, {
        :name       => 'nested hashes (8)',
        :val1       => { 'k1' => '1', 'k2' => { :n1 => { nil => '2', 3 => 4 } } },
        :val2       => { 'k2' => { :n1 => { 3 => 4, nil => '3' } }, 'k1' => '1' },
        :ret        => false,
        :ret_strict => false
    }, {
        :name       => 'arrays with hashes (1)',
        :val1       => ['a', { 'k1' => '1', 'k2' => 2 }, 'd', { 'k' => nil }],
        :val2       => ['a', { 'k1' => '1', 'k2' => 2 }, 'd', { 'k' => nil }],
        :ret        => true,
        :ret_strict => true
    }, {
        :name       => 'arrays with hashes (2)',
        :val1       => ['a', { 'k1' => '1', 'k2' => 2 }, 'd', { 'k' => nil }],
        :val2       => ['a', { 'k' => nil }, { 'k2' => 2, 'k1' => '1' }, 'd'],
        :ret        => true,
        :ret_strict => false
    }, {
        :name       => 'arrays with hashes (3)',
        :val1       => ['a', { 'k1' => '1', 'k2' => [2] }, 'd', { 'k' => ['X', [['Y', 'Z']]] }],
        :val2       => ['a', { 'k1' => '1', 'k2' => [2] }, 'd', { 'k' => ['X', [['Y', 'Z']]] }],
        :ret        => true,
        :ret_strict => true
    }, {
        :name       => 'arrays with hashes (4)',
        :val1       => ['a', { 'k1' => '1', 'k2' => [2] }, 'd', { 'k' => ['X', [['Y', 'Z']]] }],
        :val2       => ['a', { 'k1' => '1', 'k2' => [2] }, 'd', { 'k' => [[['Y', 'Z']], 'X'] }],
        :ret        => true,
        :ret_strict => false
    }, {
        :name       => 'arrays with hashes (5)',
        :val1       => ['a', { 'k1' => '1', 'k2' => [2] }, 'd', { 'k' => ['X', [['Y', 'Z']]] }],
        :val2       => ['a', { 'k1' => '1', 'k2' => [2] }, 'd', { 'k' => ['X', [['Z', 'Y']]] }],
        :ret        => true,
        :ret_strict => false
    }, {
        :name       => 'arrays with hashes (6)',
        :val1       => ['a', { 'k1' => '1', 'k2' => [2] }, 'd', { 'k' => ['X', [['Y', 'Z']]] }],
        :val2       => [{ 'k1' => '1', 'k2' => [2] }, 'a', { 'k' => ['X', [['Y', 'Z']]] }, 'd'],
        :ret        => true,
        :ret_strict => false
    }, {
        :name       => 'arrays with hashes (7)',
        :val1       => ['a', { 'k1' => '1', 'k2' => [2] }, 'd', { 'k' => ['X', [['Y', 'Z']]] }],
        :val2       => [{ 'k1' => '1', 'k2' => [2] }, 'a', { 'k' => ['X', [['Y', '#']]] }, 'd'],
        :ret        => false,
        :ret_strict => false
    }, {
        :name       => 'arrays with hashes (8)',
        :val1       => ['a', { 'k1' => ['1', '2', '3'] }, 'd', { ['1', '2', '3'] => nil, ['1', '2'] => :symbol, nil => [{}] }],
        :val2       => ['a', { 'k1' => ['1', '2', '3'] }, 'd', { ['1', '2', '3'] => nil, ['1', '2'] => :symbol, nil => [{}] }],
        :ret        => true,
        :ret_strict => true
    }, {
        :name       => 'arrays with hashes (9)',
        :val1       => ['a', { 'k1' => ['1', '2', '3'] }, 'd', { ['1', '2', '3'] => nil, ['1', '2'] => :symbol }],
        :val2       => ['a', { 'k1' => ['3', '2', '1'] }, 'd', { ['3', '2', '1'] => nil, ['2', '1'] => :symbol }],
        :ret        => false,  # non-strict order only applies to values, not array based keys!!!
        :ret_strict => false
    }, {
        :name        => 'arrays with hashes (10)',
        :val1        => [{ 'k1' => '1', 'a' => 'b' }, { 'k2' => '2', 'c' => 'd' }, { 'k3' => '3', 'e' => 'f' }],
        :val2        => [{ 'k1' => '1', 'a' => 'b' }, { 'k2' => '2', 'c' => 'd' }, { 'k3' => '3', 'e' => 'f' }],
        :ret        => true,
        :ret_strict => true
    }, {
        :name       => 'arrays with hashes (11)',
        :val1       => [{ 'k1' => '1', 'a' => 'b' }, { 'k2' => '2', 'c' => 'd' }, { 'k3' => '3', 'e' => 'f' }],
        :val2       => [{ 'k2' => '2', 'c' => 'd' }, { 'k3' => '3', 'e' => 'f' }, { 'k1' => '1', 'a' => 'b' }],
        :ret        => true,
        :ret_strict => false
    }, {
        :name       => 'arrays with hashes (12)',
        :val1       => [{ 'k1' => '1', 'a' => 'b' }, { 'k2' => '2', 'c' => 'd' }, { 'k3' => '3', 'e' => 'f' }],
        :val2       => [{ 'k2' => '2', 'c' => 'd' }, { 'k3' => '3', 'e' => 'f' }, { 'k1' => '1', 'a' => [] }],
        :ret        => false,
        :ret_strict => false
    }, {
        :name       => 'arrays with hashes (13)',
        :val1       => [{ 'k1' => '1', 'a' => 'b' }, { 'k2' => '2', 'c' => 'd' }, { 'k3' => '3', 'e' => 'f' }, nil],
        :val2       => [{ 'k2' => '2', 'c' => 'd' }, { 'k3' => '3', 'e' => 'f' }, { 'k1' => '1', 'a' => 'b' }, {}],
        :ret        => false,
        :ret_strict => false
    }, {
        :name       => 'arrays with hashes (14)',
        :val1       => ['a', [{ 'k1' => '1', 'k2' => [{}, nil] }, ['d', { 'k' => nil }]]],
        :val2       => ['a', [{ 'k1' => '1', 'k2' => [{}, nil] }, ['d', { 'k' => nil }]]],
        :ret        => true,
        :ret_strict => true
    }, {
        :name       => 'arrays with hashes (15)',
        :val1       => ['a', [{ 'k1' => '1', 'k2' => [{}, nil] }, ['d', { 'k' => nil }]]],
        :val2       => ['a', [{ 'k1' => '1', 'k2' => [nil, {}] }, ['d', { 'k' => nil }]]],
        :ret        => true,
        :ret_strict => false
    }, {
        :name       => 'arrays with hashes (16)',
        :val1       => ['a', [{ 'k1' => '1', 'k2' => [{}, nil] }, ['d', { 'k' => nil }]]],
        :val2       => [[{ 'k2' => [nil, {}], 'k1' => '1' }, [{ 'k' => nil }, 'd']], 'a'],
        :ret        => true,
        :ret_strict => false
    }]

    context 'deep_compare' do
        it 'accepts 2..3 arguments' do
            expect(OneCfg::Config::Utils).to respond_to(:deep_compare)
                .with(2..3).arguments
        end

        DEEP_COMPARE_EXAMPLES.each do |ex|
            context "test #{ex[:name]}" do
                it 'deep compares' do
                    ret = OneCfg::Config::Utils.deep_compare(ex[:val1],
                                                               ex[:val2])

                    expect(ret).to be(ex[:ret])
                end

                it 'deep compares with strict order' do
                    ret = OneCfg::Config::Utils.deep_compare(ex[:val1],
                                                               ex[:val2],
                                                               true)

                    expect(ret).to be(ex[:ret_strict])
                end

                if [Array, Hash].include?(ex[:val1].class) &&
                   [Array, Hash].include?(ex[:val2].class)

                    it 'compares via HashDiff with strict result' do
                        ret = Hashdiff.best_diff(ex[:val1], ex[:val2])

                        if ex[:ret_strict]
                            expect(ret).to be_empty
                        else
                            expect(ret).not_to be_empty
                        end
                    end
                end
            end
        end
    end

    ###

    DEEP_INCLUDE_DATA = [
        'a', 'b', nil, 1, '2', 123.456, Object, Object.new,
        ['3'],
        [4, [5, 6], '7'],
        [{ 'k1' => 'v1' }, { 'k2' => 'v2' }],
        { 'k3' => 666, 'k4' => nil, 'k5' => ['a', 'b'] },
        { 'k6' => 'v6' }
    ]

    DEEP_INCLUDE_EXAMPLES = [{
        :val        => 'a',
        :idx        => 0,
        :ret        => true,
        :ret_strict => true
    }, {
        :val        => 'b',
        :idx        => 1,
        :ret        => true,
        :ret_strict => true
    }, {
        :val        => 'c',
        :ret        => false,
        :ret_strict => false
    }, {
        :val        => nil,
        :idx        => 2,
        :ret        => true,
        :ret_strict => true
    }, {
        :val        => 1,
        :idx        => 3,
        :ret        => true,
        :ret_strict => true
    }, {
        :val        => '1',
        :ret        => false,
        :ret_strict => false
    }, {
        :val        => 123.456,
        :idx        => 5,
        :ret        => true,
        :ret_strict => true
    }, {
        :val        => '123.456',
        :ret        => false,
        :ret_strict => false
    }, {
        :val        => Object,
        :idx        => 6,
        :ret        => true,
        :ret_strict => true
    }, {
        :val        => Object.new,
        :ret        => false,
        :ret_strict => false
    }, {
        :val        => DEEP_INCLUDE_DATA[7],
        :idx        => 7,
        :ret        => true,
        :ret_strict => true
    }, {
        :val        => '3',
        :ret        => false,
        :ret_strict => false
    }, {
        :val        => ['3'],
        :idx        => 8,
        :ret        => true,
        :ret_strict => true
    }, {
        :val        => 4,
        :ret        => false,
        :ret_strict => false
    }, {
        :val        => [5, 6],
        :ret        => false,
        :ret_strict => false
    }, {
        :val        => [4, [5, 6]],
        :ret        => false,
        :ret_strict => false
    }, {
        :val        => [4, 7],
        :ret        => false,
        :ret_strict => false
    }, {
        :val        => [4, 5, 6, '7'],
        :ret        => false,
        :ret_strict => false
    }, {
        :val        => [4, [5, 6], 7],
        :ret        => false,
        :ret_strict => false
    }, {
        :val        => [4, [5, 6], '7'],
        :idx        => 9,
        :ret        => true,
        :ret_strict => true
    }, {
        :val        => ['7', 4, [5, 6]],
        :idx        => 9,
        :ret        => true,
        :ret_strict => false
    }, {
        :val        => [4, '7', [6, 5]],
        :idx        => 9,
        :ret        => true,
        :ret_strict => false
    }, {
        :val        => [],
        :ret        => false,
        :ret_strict => false
    }, {
        :val        => [{}],
        :ret        => false,
        :ret_strict => false
    }, {
        :val        => { 'k1' => 'v1' },
        :ret        => false,
        :ret_strict => false
    }, {
        :val        => { 'k2' => 'v2' },
        :ret        => false,
        :ret_strict => false
    }, {
        :val        => { 'k1' => 'v1', 'k2' => 'v2' },
        :ret        => false,
        :ret_strict => false
    }, {
        :val        => [{ 'k1' => 'v1', 'k2' => 'v2' }],
        :ret        => false,
        :ret_strict => false
    }, {
        :val        => [{ 'k1' => 'v1' }, { 'k2' => 'v2' }],
        :idx        => 10,
        :ret        => true,
        :ret_strict => true
    }, {
        :val        => [{ 'k1' => 'v2' }, { 'k2' => 'v1' }],
        :ret        => false,
        :ret_strict => false
    }, {
        :val        => [{ 'k2' => 'v2' }, { 'k1' => 'v1' }],
        :idx        => 10,
        :ret        => true,
        :ret_strict => false
    }, {
        :val        => [{ 'k2' => 'v1' }, { 'k1' => 'v2' }],
        :ret        => false,
        :ret_strict => false
    }, {
        :val        => { 'k3' => 666, 'k4' => nil, 'k5' => ['a', 'b'] },
        :idx        => 11,
        :ret        => true,
        :ret_strict => true
    }, {
        :val        => { 'k5' => ['a', 'b'], 'k3' => 666, 'k4' => nil },
        :idx        => 11,
        :ret        => true,
        :ret_strict => true
    }, {
        :val        => { 'k5' => ['b', 'a'], 'k3' => 666, 'k4' => nil },
        :idx        => 11,
        :ret        => true,
        :ret_strict => false
    }, {
        :val        => { 'k5' => ['b', 'a'], 'k3' => 666, 'k4' => nil },
        :idx        => 11,
        :ret        => true,
        :ret_strict => false
    }, {
        :val        => [{ 'k3' => 666, 'k4' => nil, 'k5' => ['a', 'b'] }],
        :ret        => false,
        :ret_strict => false
    }, {
        :val        => { 'k3' => 666, 'k4' => nil, 'k5' => [] },
        :ret        => false,
        :ret_strict => false
    }, {
        :val        => { 'k3' => 666, 'k4' => nil, 'k5' => ['a', 'b', 'c'] },
        :ret        => false,
        :ret_strict => false
    }, {
        :val        => { 'k3' => 666, 'k4' => nil, 'k5' => ['a'] },
        :ret        => false,
        :ret_strict => false
    }, {
        :val        => { 'k3' => 666, nil => 'k4', 'k5' => ['a', 'b'] },
        :ret        => false,
        :ret_strict => false
    }, {
        :val        => { 'k3' => 666 },
        :ret        => false,
        :ret_strict => false
    }, {
        :val        => { 'k4' => nil, 'k5' => ['a', 'b'] },
        :ret        => false,
        :ret_strict => false
    }, {
        :val        => { 'k4' => nil },
        :ret        => false,
        :ret_strict => false
    }, {
        :val        => { 'k5' => ['a', 'b'] },
        :ret        => false,
        :ret_strict => false
    }, {
        :val        => { 'k6' => 'v6' },
        :idx        => 12,
        :ret        => true,
        :ret_strict => true
    }, {
        :val        => [{ 'k6' => 'v6' }],
        :ret        => false,
        :ret_strict => false
    }, {
        :val        => { 'k6' => nil },
        :ret        => false,
        :ret_strict => false
    }]

    context 'deep_include? and deep_index' do
        it 'accepts 2..3 arguments' do
            expect(OneCfg::Config::Utils).to respond_to(:deep_include?)
                .with(2..3).arguments

            expect(OneCfg::Config::Utils).to respond_to(:deep_index)
                .with(2..3).arguments
        end

        DEEP_INCLUDE_EXAMPLES.each do |ex|
            context "test #{ex[:val].pretty_inspect}" do
                it 'checks include?' do
                    ret = OneCfg::Config::Utils.deep_include?(
                        DEEP_INCLUDE_DATA,
                        ex[:val]
                    )

                    expect(ret).to be(ex[:ret])
                end

                it 'checks include? with strict order' do
                    ret = OneCfg::Config::Utils.deep_include?(
                        DEEP_INCLUDE_DATA,
                        ex[:val],
                        true
                    )

                    expect(ret).to be(ex[:ret_strict])
                end

                it 'checks index' do
                    idx1 = OneCfg::Config::Utils.deep_index(
                        DEEP_INCLUDE_DATA,
                        ex[:val]
                    )

                    idx2 = OneCfg::Config::Utils.deep_index(
                        DEEP_INCLUDE_DATA,
                        ex[:val],
                        true
                    )

                    expect(idx1).to eq(ex[:idx])

                    if ex[:ret_strict]
                        expect(idx2).to eq(ex[:idx])
                    else
                        expect(idx2).to be_nil
                    end
                end
            end
        end
    end
end
