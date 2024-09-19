# Certification tests

## Requirements

- Have an OpenNebula instance
- Create OpenNebula resources as described at `bootstrap.yaml`
- Load OpenNebula gems
```bash
export GEM_PATH=/usr/share/one/gems/
export GEM_HOME=$GEM_PATH
export PATH=$PATH:$GEM_PATH/bin
```
- Install rspec `gem install rspec`

## How to run

The tests exist at `./tests/spec/` as ruby files. These will be loaded depending on what is stated on `./tests/tests.yaml`. The appliances to be tested are defined at `./defaults.yaml`.

```bash
cd ./tests
./readiness.rb --microenv ./tests.yaml --defaults ./defaults.yaml --format h --output results.html --format d --output results.txt --format j --output results.json
```
