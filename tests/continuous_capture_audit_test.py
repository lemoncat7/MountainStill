"""Reject missing or mislabeled continuous evidence instead of vacuous success."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]
class CaptureAuditTest(unittest.TestCase):
    def audit(self, **changes):
        data=dict(source_frozen=True,engine_time_scale=1.0,failed=False,seconds=60,bouts=[],events=[],frames=[])
        data.update(changes)
        with tempfile.TemporaryDirectory() as tmp:
            source=Path(tmp)/'capture.json';source.write_text(json.dumps(data))
            p=subprocess.run([sys.executable,str(ROOT/'tools/qa_analyze_continuous_capture.py'),str(source)],capture_output=True,text=True)
            self.assertEqual(p.returncode,1)
            return json.loads(p.stdout)['assertion_errors']
    def test_empty_capture_never_passes(self):
        self.assertIn('expected exactly two ordered boss bouts',self.audit())
    def test_headless_cannot_be_labeled_graphical(self):
        self.assertIn('headless mode and display server disagree',self.audit(display_server='headless',headless_audit=False))
    def test_graphical_cannot_be_labeled_headless(self):
        self.assertIn('headless mode and display server disagree',self.audit(display_server='x11',headless_audit=True))
    def test_headless_flag_must_be_boolean(self):
        self.assertIn('headless mode and display server disagree',self.audit(display_server='headless',headless_audit='true'))
if __name__=='__main__':unittest.main()
