# Certification tests

## Requirements

- Have an OpenNebula instance with onegate
- Create OpenNebula resources as described at `bootstrap.yaml`
  - br0 should exist previously with ip address
  - tap0 should be created for vlan comms
- Load OpenNebula gems
```bash
export GEM_PATH=/usr/share/one/gems/
export GEM_HOME=$GEM_PATH
export PATH=$PATH:$GEM_PATH/bin
```
- Install rspec ruby gem `gem install rspec`
- The oneadmin user must have an `ssh_public_key` corresponding to its ssh cli private key. The goal is to be able to

## How to run

The tests exist at `./tests/spec/` as ruby files. These will be loaded depending on what is stated on `./tests/tests.yaml`. The appliances to be tested are defined at `./defaults.yaml`.

```bash
cd ./tests
./readiness.rb --microenv ./tests.yaml --defaults ./defaults.yaml --format h --output results.html --format d --output results.txt --format j --output results.json
```

## How to create your own tests
