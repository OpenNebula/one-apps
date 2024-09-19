RSpec.describe 'Fake tests (random results)' do
    (1..10).each do |i|
        it "random test case #{i}"  do
            expect(rand).to be <= 0.8
        end
    end
end
