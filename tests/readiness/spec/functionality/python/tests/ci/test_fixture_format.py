

import unittest
import os
from pyone.tester import read_fixture_file, write_fixture_file

fixture_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'tmp-fixture-format.json.gz')

data = {
        'TEMPLATE': {
            'LABELS': 'SSD',
            'MAX_CPU': '176'
        }
    }


class TextFixtureFormat(unittest.TestCase):

    def test_fixture_format(self):
        write_fixture_file(fixture_file, data)
        fixtures = read_fixture_file(fixture_file)
        self.assertEqual(data['TEMPLATE']['LABELS'], fixtures['TEMPLATE']['LABELS'])
        os.remove(fixture_file)
