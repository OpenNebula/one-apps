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


# Enums were only introduced in python 3.4 and then backported,
# this tests help stablishing if they are working in previous versions too.

from unittest import TestCase
from enum import IntEnum
from pyone import MARKETPLACEAPP_STATES, LCM_STATE

class ConstantTest(TestCase):
    def test_int_constants(self):
        self.assertEqual(MARKETPLACEAPP_STATES.READY,1)
        self.assertEqual(LCM_STATE.RUNNING, 3)

    def test_state_as_string(self):
        self.assertEqual(str(MARKETPLACEAPP_STATES.READY.name), 'READY')

    def test_int_to_state(self):
        self.assertEqual(MARKETPLACEAPP_STATES(3).name, 'ERROR')

    def test_state_interpolation(self):
        self.assertEqual( 'state is %s' % MARKETPLACEAPP_STATES(3).name, 'state is ERROR')

    def test_detect_and_cast_constant(self):
        c = MARKETPLACEAPP_STATES.READY
        self.assertTrue(isinstance(c, IntEnum))
        self.assertEqual(c.value, 1)
