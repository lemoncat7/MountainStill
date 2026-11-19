import importlib.util
import tempfile
import unittest
import zipfile
import warnings
from pathlib import Path
from unittest.mock import patch
ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('rebuild', ROOT/'tools/rebuild_v1341_artifact.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
class SafetyTests(unittest.TestCase):
    def test_wrong_cached_digest_rejected_without_network(self):
        with tempfile.TemporaryDirectory() as t:
            p = Path(t)/'engine.zip'; p.write_bytes(b'wrong')
            with patch.object(m.urllib.request, 'urlopen') as request:
                with self.assertRaisesRegex(RuntimeError, 'digest mismatch'):
                    m.checked_archive(Path(t), p.name, '0'*64)
                request.assert_not_called()
    def test_zip_duplicate_rejected(self):
        with tempfile.TemporaryDirectory() as t:
            p=Path(t)/'duplicate.zip'
            with warnings.catch_warnings():
                warnings.simplefilter('ignore')
                with zipfile.ZipFile(p,'w') as z:
                    z.writestr('same',b'a'); z.writestr('same',b'b')
            with self.assertRaisesRegex(RuntimeError,'Duplicate'):
                m.zip_inventory(p)
    def test_existing_output_rejected_before_network(self):
        with tempfile.TemporaryDirectory() as t:
            p=Path(t)/'original';p.mkdir();(p/'keep').write_bytes(b'frozen')
            with patch('sys.argv',['build','--workspace',str(p),'--cache',str(Path(t)/'cache')]), patch.object(m,'checked_archive') as download:
                with self.assertRaises(SystemExit):m.main()
                download.assert_not_called()
            self.assertEqual((p/'keep').read_bytes(),b'frozen')
    def test_metadata_and_payload_are_separate(self):
        with tempfile.TemporaryDirectory() as t:
            inventories=[]
            for i in range(2):
                p=Path(t)/str(i)
                with zipfile.ZipFile(p,'w') as z:
                    item=zipfile.ZipInfo('file',(2026,11,19,12,0,i*2));z.writestr(item,b'same')
                inventories.append(m.zip_inventory(p))
            self.assertEqual(inventories[0]['file']['sha256'],inventories[1]['file']['sha256'])
            self.assertNotEqual(inventories[0]['file']['date_time'],inventories[1]['file']['date_time'])
if __name__=='__main__':unittest.main()
