#!/usr/bin/env bash

sed -i -e 's:^SELINUX=.*:SELINUX=enforcing:' /etc/selinux/config
