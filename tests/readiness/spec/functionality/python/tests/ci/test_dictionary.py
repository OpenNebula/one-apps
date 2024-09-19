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
import pyone
import xmltodict

xmlSample = b'''<MARKETPLACE_POOL xmlns="http://opennebula.org/XMLSchema">
    <MARKETPLACE>
        <ID>0</ID>
        <UID>0</UID>
        <GID>0</GID>
        <UNAME>oneadmin</UNAME>
        <GNAME>oneadmin</GNAME>
        <NAME>OpenNebula Public</NAME>
        <MARKET_MAD><![CDATA[one]]></MARKET_MAD>
        <ZONE_ID><![CDATA[0]]></ZONE_ID>
        <TOTAL_MB>0</TOTAL_MB>
        <FREE_MB>0</FREE_MB>
        <USED_MB>0</USED_MB>
        <MARKETPLACEAPPS>
            <ID>0</ID>
            <ID>1</ID>
            <ID>2</ID>
            <ID>3</ID>
            <ID>4</ID>
            <ID>5</ID>
            <ID>6</ID>
            <ID>7</ID>
            <ID>8</ID>
            <ID>9</ID>
            <ID>10</ID>
            <ID>11</ID>
            <ID>12</ID>
            <ID>13</ID>
            <ID>14</ID>
            <ID>15</ID>
            <ID>16</ID>
            <ID>17</ID>
            <ID>18</ID>
            <ID>19</ID>
            <ID>20</ID>
            <ID>21</ID>
            <ID>22</ID>
            <ID>23</ID>
            <ID>24</ID>
        </MARKETPLACEAPPS>
        <PERMISSIONS>
            <OWNER_U>1</OWNER_U>
            <OWNER_M>1</OWNER_M>
            <OWNER_A>1</OWNER_A>
            <GROUP_U>1</GROUP_U>
            <GROUP_M>0</GROUP_M>
            <GROUP_A>0</GROUP_A>
            <OTHER_U>1</OTHER_U>
            <OTHER_M>0</OTHER_M>
            <OTHER_A>0</OTHER_A>
        </PERMISSIONS>
        <TEMPLATE><DESCRIPTION><![CDATA[OpenNebula Systems MarketPlace]]></DESCRIPTION><MARKET_MAD><![CDATA[one]]></MARKET_MAD></TEMPLATE>
    </MARKETPLACE>
</MARKETPLACE_POOL>'''

xmlSample2 = b'''<MARKETPLACE_POOL>
    <MARKETPLACE>
        <ID>0</ID>
        <UID>0</UID>
        <GID>0</GID>
        <UNAME>oneadmin</UNAME>
        <GNAME>oneadmin</GNAME>
        <NAME>OpenNebula Public</NAME>
        <MARKET_MAD><![CDATA[one]]></MARKET_MAD>
        <ZONE_ID><![CDATA[0]]></ZONE_ID>
        <TOTAL_MB>0</TOTAL_MB>
        <FREE_MB>0</FREE_MB>
        <USED_MB>0</USED_MB>
        <MARKETPLACEAPPS>
            <ID>0</ID>
            <ID>1</ID>
        </MARKETPLACEAPPS>
        <PERMISSIONS>
            <OWNER_U>1</OWNER_U>
        </PERMISSIONS>
        <TEMPLATE/>
    </MARKETPLACE>
</MARKETPLACE_POOL>'''

xmlSample3 = b'''<VM>
    <ID>1</ID>
    <UID>0</UID>
    <GID>0</GID>
    <UNAME>oneadmin</UNAME>
    <GNAME>oneadmin</GNAME>
    <NAME>VM 2</NAME>
    <PERMISSIONS A="B">
        <OWNER_U>1</OWNER_U>
        <OWNER_M>1</OWNER_M>
        <OWNER_A>0</OWNER_A>
        <GROUP_U>0</GROUP_U>
        <GROUP_M>0</GROUP_M>
        <GROUP_A>0</GROUP_A>
        <OTHER_U>0</OTHER_U>
        <OTHER_M>0</OTHER_M>
        <OTHER_A>0</OTHER_A>
    </PERMISSIONS>
    <LAST_POLL>0</LAST_POLL>
    <STATE>6</STATE>
    <LCM_STATE>0</LCM_STATE>
    <PREV_STATE>6</PREV_STATE>
    <PREV_LCM_STATE>0</PREV_LCM_STATE>
    <RESCHED>0</RESCHED>
    <STIME>1706016929</STIME>
    <ETIME>1706017381</ETIME>
    <DEPLOY_ID/>
    <MONITORING/>
    <SCHED_ACTIONS/>
    <TEMPLATE>
        <AUTOMATIC_DS_REQUIREMENTS><![CDATA[("CLUSTERS/ID" @> 0)]]></AUTOMATIC_DS_REQUIREMENTS>
        <AUTOMATIC_NIC_REQUIREMENTS><![CDATA[("CLUSTERS/ID" @> 0)]]></AUTOMATIC_NIC_REQUIREMENTS>
        <AUTOMATIC_REQUIREMENTS><![CDATA[(CLUSTER_ID = 0) & !(PUBLIC_CLOUD = YES) & !(PIN_POLICY = PINNED)]]></AUTOMATIC_REQUIREMENTS>
        <CONTEXT>
        <DISK_ID><![CDATA[1]]></DISK_ID>
        <NETWORK><![CDATA[YES]]></NETWORK>
        <ONEAPP_ADMIN_EMAIL><![CDATA[]]></ONEAPP_ADMIN_EMAIL>
        <ONEAPP_ADMIN_PASSWORD><![CDATA[opennebula]]></ONEAPP_ADMIN_PASSWORD>
        <ONEAPP_ADMIN_USERNAME><![CDATA[oneadmin]]></ONEAPP_ADMIN_USERNAME>
        <ONEAPP_SITE_TITLE><![CDATA[]]></ONEAPP_SITE_TITLE>
        <ONEAPP_SSL_CERT><![CDATA[]]></ONEAPP_SSL_CERT>
        <ONEAPP_SSL_CHAIN><![CDATA[]]></ONEAPP_SSL_CHAIN>
        <ONEAPP_SSL_PRIVKEY><![CDATA[]]></ONEAPP_SSL_PRIVKEY>
        <SSH_PUBLIC_KEY><![CDATA[]]></SSH_PUBLIC_KEY>
        <TARGET><![CDATA[hda]]></TARGET>
        </CONTEXT>
        <CPU><![CDATA[1]]></CPU>
        <DISK>
        <ALLOW_ORPHANS><![CDATA[YES]]></ALLOW_ORPHANS>
        <CLONE><![CDATA[YES]]></CLONE>
        <CLONE_TARGET><![CDATA[SYSTEM]]></CLONE_TARGET>
        <CLUSTER_ID><![CDATA[0]]></CLUSTER_ID>
        <DATASTORE><![CDATA[default]]></DATASTORE>
        <DATASTORE_ID><![CDATA[1]]></DATASTORE_ID>
        <DEV_PREFIX><![CDATA[vd]]></DEV_PREFIX>
        <DISK_ID><![CDATA[0]]></DISK_ID>
        <DISK_SNAPSHOT_TOTAL_SIZE><![CDATA[0]]></DISK_SNAPSHOT_TOTAL_SIZE>
        <DISK_TYPE><![CDATA[FILE]]></DISK_TYPE>
        <DRIVER><![CDATA[qcow2]]></DRIVER>
        <FORMAT><![CDATA[qcow2]]></FORMAT>
        <IMAGE><![CDATA[Service WordPress - KVM]]></IMAGE>
        <IMAGE_ID><![CDATA[3]]></IMAGE_ID>
        <IMAGE_STATE><![CDATA[2]]></IMAGE_STATE>
        <LN_TARGET><![CDATA[SYSTEM]]></LN_TARGET>
        <NAME><![CDATA[DISK0]]></NAME>
        <ORDER><![CDATA[1]]></ORDER>
        <ORIGINAL_SIZE><![CDATA[5120]]></ORIGINAL_SIZE>
        <READONLY><![CDATA[NO]]></READONLY>
        <SAVE><![CDATA[NO]]></SAVE>
        <SIZE><![CDATA[5120]]></SIZE>
        <SOURCE><![CDATA[/var/lib/one//datastores/1/cbd91e3ea47e97934efcc7f698627144]]></SOURCE>
        <TARGET><![CDATA[vda]]></TARGET>
        <TM_MAD><![CDATA[ssh]]></TM_MAD>
        <TYPE><![CDATA[FILE]]></TYPE>
        </DISK>
        <GRAPHICS>
        <LISTEN><![CDATA[0.0.0.0]]></LISTEN>
        <TYPE><![CDATA[vnc]]></TYPE>
        </GRAPHICS>
        <MEMORY><![CDATA[768]]></MEMORY>
        <OS>
        <ARCH><![CDATA[x86_64]]></ARCH>
        <BOOT><![CDATA[disk0]]></BOOT>
        <UUID><![CDATA[245a7f83-44af-4a86-a9f0-0d585c0b5ba4]]></UUID>
        </OS>
        <TEMPLATE_ID><![CDATA[1]]></TEMPLATE_ID>
        <TM_MAD_SYSTEM><![CDATA[ssh]]></TM_MAD_SYSTEM>
        <VMID><![CDATA[1]]></VMID>
    </TEMPLATE>
    <USER_TEMPLATE>
        <A>
        <C><![CDATA[D]]></C>
        <E><![CDATA[F]]></E>
        </A>
        <INPUTS_ORDER><![CDATA[ONEAPP_SSL_CERT,ONEAPP_SSL_PRIVKEY,ONEAPP_SSL_CHAIN,ONEAPP_SITE_TITLE,ONEAPP_ADMIN_USERNAME,ONEAPP_ADMIN_EMAIL,ONEAPP_ADMIN_PASSWORD]]></INPUTS_ORDER>
        <ONEAPP_ADMIN_PASSWORD><![CDATA[opennebula]]></ONEAPP_ADMIN_PASSWORD>
        <ONEAPP_ADMIN_USERNAME><![CDATA[oneadmin]]></ONEAPP_ADMIN_USERNAME>
        <USER_INPUTS>
        <ONEAPP_ADMIN_EMAIL><![CDATA[O|text|** Site Administrator E-mail (set all or none)]]></ONEAPP_ADMIN_EMAIL>
        <ONEAPP_ADMIN_PASSWORD><![CDATA[O|password|** Site Administrator Password (set all or none)]]></ONEAPP_ADMIN_PASSWORD>
        <ONEAPP_ADMIN_USERNAME><![CDATA[O|text|** Site Administrator Login (set all or none)]]></ONEAPP_ADMIN_USERNAME>
        <ONEAPP_SITE_TITLE><![CDATA[O|text|** Site Title (set all or none)]]></ONEAPP_SITE_TITLE>
        <ONEAPP_SSL_CERT><![CDATA[O|text64|SSL certificate]]></ONEAPP_SSL_CERT>
        <ONEAPP_SSL_CHAIN><![CDATA[O|text64|SSL CA chain]]></ONEAPP_SSL_CHAIN>
        <ONEAPP_SSL_PRIVKEY><![CDATA[O|text64|SSL private key]]></ONEAPP_SSL_PRIVKEY>
        </USER_INPUTS>
    </USER_TEMPLATE>
    <HISTORY_RECORDS>
        <HISTORY>
        <OID>1</OID>
        <SEQ>0</SEQ>
        <HOSTNAME>host01</HOSTNAME>
        <HID>3</HID>
        <CID>0</CID>
        <STIME>1706016939</STIME>
        <ETIME>1706017381</ETIME>
        <VM_MAD><![CDATA[qemu]]></VM_MAD>
        <TM_MAD><![CDATA[ssh]]></TM_MAD>
        <DS_ID>0</DS_ID>
        <PSTIME>1706016939</PSTIME>
        <PETIME>1706016945</PETIME>
        <RSTIME>1706016945</RSTIME>
        <RETIME>1706017381</RETIME>
        <ESTIME>0</ESTIME>
        <EETIME>0</EETIME>
        <ACTION>13</ACTION>
        <UID>0</UID>
        <GID>0</GID>
        <REQUEST_ID>1936</REQUEST_ID>
        </HISTORY>
    </HISTORY_RECORDS>
    <BACKUPS>
        <BACKUP_CONFIG/>
        <BACKUP_IDS/>
    </BACKUPS>
</VM>'''

class DictionaryTests(unittest.TestCase):
    def test_dict_to_xml(self):
        templ = {
                'TEMPLATE': {
                    'LABELS': 'SSD',
                    'MAX_CPU': '176'
                }
            }
        self.assertIn(pyone.util.cast2one(templ), ["<TEMPLATE><MAX_CPU><![CDATA[176]]></MAX_CPU><LABELS><![CDATA[SSD]]></LABELS></TEMPLATE>", "<TEMPLATE><LABELS><![CDATA[SSD]]></LABELS><MAX_CPU><![CDATA[176]]></MAX_CPU></TEMPLATE>"])

    def test_xml_to_dict(self):
        marketplace = pyone.bindings.parseString(xmlSample)
        template = pyone.util.one2dict(marketplace.MARKETPLACE[0].TEMPLATE)
        xml=pyone.util.cast2one(template)
        self.assertEqual(xml,u'<TEMPLATE><DESCRIPTION><![CDATA[OpenNebula Systems MarketPlace]]></DESCRIPTION><MARKET_MAD><![CDATA[one]]></MARKET_MAD></TEMPLATE>')
        # new direct method
        xml2 = pyone.util.cast2one(marketplace.MARKETPLACE[0].TEMPLATE)
        self.assertEqual(xml,xml2)

    def test_xml_to_dict_easy_access(self):
        marketplace = pyone.bindings.parseString(xmlSample)
        self.assertEqual(marketplace.MARKETPLACE[0].TEMPLATE['MARKET_MAD'],"one")

    def test_xml_to_dict_easy_test_template_key(self):
        marketplace = pyone.bindings.parseString(xmlSample)
        self.assertTrue('MARKET_MAD' in marketplace.MARKETPLACE[0].TEMPLATE)
        self.assertFalse('IMPOSSIBLE_ELEMENT' in marketplace.MARKETPLACE[0].TEMPLATE)

    def test_xml_to_dict_easy_test_template_key_empty_template(self):
        marketplace = pyone.bindings.parseString(xmlSample2)
        self.assertFalse('MARKET_MAD' in marketplace.MARKETPLACE[0].TEMPLATE)

    def test_xml_parsing_with_scalar_attribute(self):
        virt_machine = pyone.bindings.parseString(xmlSample3)
        self.assertTrue(hasattr(virt_machine.PERMISSIONS, 'custom_attrs'))
        self.assertEqual(virt_machine.PERMISSIONS.custom_attrs, {'A': 'B'})

    def test_xml_parsing_with_vector_attribute(self):
        virt_machine = pyone.bindings.parseString(xmlSample3)
        self.assertTrue('A' in virt_machine.USER_TEMPLATE)
        self.assertTrue({'C', 'E'} <= virt_machine.USER_TEMPLATE['A'].keys())
        self.assertEqual(virt_machine.USER_TEMPLATE['A']['C'], 'D')
        self.assertEqual(virt_machine.USER_TEMPLATE['A']['E'], 'F')
