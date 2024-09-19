# coding: utf-8

# Copyright 2018 www.privaz.io Valletech AB
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import os
import unittest
import pyone.bindings as bindings


class TestIssue006(unittest.TestCase):

    def read_xml_data(self, name):
        data_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'test_issue_006_data')
        f = open(os.path.join(data_dir, name), 'rb')
        xml = f.read()
        f.close()
        return xml

    def test_utf8_names_in_calls(self):
        host = bindings.parseString(self.read_xml_data('host_01.xml'))
        self.assertIn(host.TEMPLATE['NOTES'], [u"Hostname is: ESPAÑA"])

    def test_vm_01(self):
        vm = bindings.parseString(self.read_xml_data('vm_01.xml'))
        self.assertEqual(vm.ID, 595)

    def test_vm_02(self):
        vm = bindings.parseString(self.read_xml_data('vm_02.xml'))
        self.assertEqual(vm.ID, 454)

    def test_vm_03(self):
        vm = bindings.parseString(self.read_xml_data('vm_03.xml'))
        self.assertEqual(vm.ID, 621)

    def test_vm_04(self):
        vm = bindings.parseString(self.read_xml_data('vm_04.xml'))
        self.assertEqual(vm.ID, 4010)

    def test_vnet_01(self):
        vnet = bindings.parseString(self.read_xml_data('vnet_01.xml'))
        self.assertEqual(vnet.ID, 11)

    def test_vnet_02(self):
        vnet = bindings.parseString(self.read_xml_data('vnet_02.xml'))
        self.assertEqual(vnet.ID, 444)

    def test_vm_pool_01(self):
        vmp = bindings.parseString(self.read_xml_data('vm_pool_01.xml'))
        self.assertEqual(vmp.VM[0].ID, 1)