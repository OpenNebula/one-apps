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

import unittest
import pyone.bindings as bindings


nakedXmlSample = b'''<MARKETPLACE_POOL><MARKETPLACE><ID>0</ID><UID>0</UID><GID>0</GID><UNAME>oneadmin</UNAME><GNAME>oneadmin</GNAME><NAME>OpenNebula Public</NAME><MARKET_MAD><![CDATA[one]]></MARKET_MAD><ZONE_ID><![CDATA[0]]></ZONE_ID><TOTAL_MB>0</TOTAL_MB><FREE_MB>0</FREE_MB><USED_MB>0</USED_MB><MARKETPLACEAPPS><ID>0</ID><ID>1</ID><ID>2</ID><ID>3</ID><ID>4</ID><ID>5</ID><ID>6</ID><ID>7</ID><ID>8</ID><ID>9</ID><ID>10</ID><ID>11</ID><ID>12</ID><ID>13</ID><ID>14</ID><ID>15</ID><ID>16</ID><ID>17</ID><ID>18</ID><ID>19</ID><ID>20</ID><ID>21</ID><ID>22</ID><ID>23</ID><ID>24</ID></MARKETPLACEAPPS><PERMISSIONS><OWNER_U>1</OWNER_U><OWNER_M>1</OWNER_M><OWNER_A>1</OWNER_A><GROUP_U>1</GROUP_U><GROUP_M>0</GROUP_M><GROUP_A>0</GROUP_A><OTHER_U>1</OTHER_U><OTHER_M>0</OTHER_M><OTHER_A>0</OTHER_A></PERMISSIONS><TEMPLATE><DESCRIPTION><![CDATA[OpenNebula Systems MarketPlace]]></DESCRIPTION><MARKET_MAD><![CDATA[one]]></MARKET_MAD></TEMPLATE></MARKETPLACE></MARKETPLACE_POOL>'''

xmlSample = b'''<MARKETPLACE_POOL xmlns='http://opennebula.org/XMLSchema'><MARKETPLACE><ID>0</ID><UID>0</UID><GID>0</GID><UNAME>oneadmin</UNAME><GNAME>oneadmin</GNAME><NAME>OpenNebula Public</NAME><MARKET_MAD><![CDATA[one]]></MARKET_MAD><ZONE_ID><![CDATA[0]]></ZONE_ID><TOTAL_MB>0</TOTAL_MB><FREE_MB>0</FREE_MB><USED_MB>0</USED_MB><MARKETPLACEAPPS><ID>0</ID><ID>1</ID><ID>2</ID><ID>3</ID><ID>4</ID><ID>5</ID><ID>6</ID><ID>7</ID><ID>8</ID><ID>9</ID><ID>10</ID><ID>11</ID><ID>12</ID><ID>13</ID><ID>14</ID><ID>15</ID><ID>16</ID><ID>17</ID><ID>18</ID><ID>19</ID><ID>20</ID><ID>21</ID><ID>22</ID><ID>23</ID><ID>24</ID></MARKETPLACEAPPS><PERMISSIONS><OWNER_U>1</OWNER_U><OWNER_M>1</OWNER_M><OWNER_A>1</OWNER_A><GROUP_U>1</GROUP_U><GROUP_M>0</GROUP_M><GROUP_A>0</GROUP_A><OTHER_U>1</OTHER_U><OTHER_M>0</OTHER_M><OTHER_A>0</OTHER_A></PERMISSIONS><TEMPLATE><DESCRIPTION><![CDATA[OpenNebula Systems MarketPlace]]></DESCRIPTION><MARKET_MAD><![CDATA[one]]></MARKET_MAD></TEMPLATE></MARKETPLACE></MARKETPLACE_POOL>'''

ns = 'http://opennebula.org/XMLSchema'

class XmlTests(unittest.TestCase):
    def test_raw_instanciation(self):
        marketpool = bindings.parseString(xmlSample)
        m0 = marketpool.MARKETPLACE[0]
        self.assertEqual(m0.NAME, "OpenNebula Public")

    def test_raw_instanciation_without_namespace(self):
        marketpool = bindings.parseString(nakedXmlSample)
        m0 = marketpool.MARKETPLACE[0]
        self.assertEqual(m0.NAME, "OpenNebula Public")


