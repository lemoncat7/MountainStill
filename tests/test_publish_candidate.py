import hashlib, json, shutil, tempfile, unittest, zipfile
from pathlib import Path
from verify_candidate import *

class Checks(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = root = Path(self.tmp.name)
        for name, contents in [(WIN, ["MountainStill/MountainStill.exe"]), (MAC,[
                "山隐 · Mountain Still.app/Contents/Info.plist",
                "山隐 · Mountain Still.app/Contents/MacOS/山隐 · Mountain Still",
                "山隐 · Mountain Still.app/Contents/Resources/山隐 · Mountain Still.pck"]),
                (SRC, ["MountainStill/project.godot","MountainStill/main.tscn"])]:
            with zipfile.ZipFile(root/name,"w") as z:
                for member in contents:
                    z.writestr(member, b"dummy fixture only")
        for asset in PCK.values(): (root/asset).write_bytes(b"GDPCfixture")
        (root/MANIFEST).write_text(json.dumps(dict(schema=1,version="1.3.41",engine="4.6.3",bootstrap=1,save_schema=4,
             packages={platform:dict(kind="pck",asset=name,**fingerprint(root/name),restart_required=True) for platform,name in PCK.items()})))
        self.report = root/"REBUILD-STATUS.json"
        self.rebaseline()
    def rebaseline(self, sums=None):
        root = self.root
        if sums is None:
            sums = "".join(f"{fingerprint(root/name)['sha256']}  {name}\n" for name in ASSETS if name != SUMS)
        (root/SUMS).write_text(sums)
        self.report.write_text(json.dumps(dict(source_sha=SOURCE, tracked_source_unchanged=True, godot_version="4.6.3.stable.official.7d41c59c4",
             godot_archive_sha256="d0bc2113065e481c9c2c2b2c37daa4e8be3fe9e27f0ab9ab0b6096e9a37907f3",templates_archive_sha256="3fbe2c0e2dec9d537ab9ec97bcf8da91dcf23357fc51f67092dd068d839290a8",status="REBUILT_CANDIDATE_NOT_RELEASED",files=[dict(name=name,**fingerprint(root/name)) for name in ASSETS])))
    def test_valid_fixture(self):
        self.assertEqual(set(verify(self.root,self.report)),set(ASSETS))
    def test_digest_drift(self):
        (self.root/PCK["windows"]).write_bytes(b"GDPCdamage!")
        with self.assertRaisesRegex(ValueError,"fingerprints"):
            verify(self.root,self.report)
    def test_duplicate_checksums(self):
        sums=(self.root/SUMS).read_text()
        self.rebaseline(sums+sums.splitlines()[0]+"\n")
        with self.assertRaisesRegex(ValueError,"duplicate checksum"):
            verify(self.root,self.report)
    def test_manifest_bad_boolean(self):
        mf=self.root/MANIFEST
        data=json.loads(mf.read_text());data["packages"]["windows"]["restart_required"]=1
        mf.write_text(json.dumps(data));self.rebaseline()
        with self.assertRaisesRegex(ValueError,"does not bind"):
            verify(self.root,self.report)
    def test_zip_traversal(self):
        with zipfile.ZipFile(self.root/SRC,"a") as z: z.writestr("MountainStill/../bad","bad")
        self.rebaseline()
        with self.assertRaisesRegex(ValueError,"Unsafe ZIP"):
            verify(self.root,self.report)
