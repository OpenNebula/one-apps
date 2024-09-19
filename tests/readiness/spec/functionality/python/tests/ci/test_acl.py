import unittest
from pyone.acl import OneAcl


class AclTests(unittest.TestCase):
    def test_calculate_ids_user(self):
        acl = OneAcl()
        self.assertEqual(acl.calculate_ids("#5"), 4294967301)

    def test_parse_users(self):
        acl = OneAcl()
        self.assertEqual(acl.parse_users("#5"), '0x100000005')
        self.assertEqual(acl.parse_users("@5"), '0x200000005')

    def test_parse_rule(self):
        acl = OneAcl()
        self.assertEqual(acl.parse_rule("#5 HOST+VM/@12 USE+MANAGE #0"),
                ('0x100000005', '0x320000000c', '0x3', '0x100000000'))

    def test_parse_rights(self):
        acl = OneAcl()
        self.assertEqual(acl.parse_rights("ADMIN"), '0x4')

    def test_parse_rights(self):
        acl = OneAcl()
        self.assertEqual(acl.parse_zone("#3"), '0x100000003')
