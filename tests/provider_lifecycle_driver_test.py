import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("lifecycle_driver", Path(__file__).resolve().parents[1] / "tools/qa_verify_provider_lifecycle.py")
driver = importlib.util.module_from_spec(spec)
spec.loader.exec_module(driver)


class StrictLifecycleGateTests(unittest.TestCase):
    def output(self, **changes):
        result = {"schema": 1, "checks": 62, "failures": 0, "cases": driver.EXPECTED_CASES, "engine": "4.6.3.stable.official"}
        result.update(changes)
        return "\n".join(driver.CASE_PREFIX + name for name in driver.EXPECTED_CASES) + "\n" + driver.RESULT_PREFIX + json.dumps(result) + "\n"

    def test_clean(self):
        self.assertTrue(driver.validate(0, self.output(), "")["passed"])

    def test_script_error_exit_zero(self):
        self.assertFalse(driver.validate(0, self.output(), "SCRIPT ERROR: Invalid operands for is\n")["passed"])

    def test_stdout_error_exit_zero(self):
        self.assertFalse(driver.validate(0, "ERROR: failure\n" + self.output(), "")["passed"])

    def test_nonzero_exit(self):
        self.assertFalse(driver.validate(1, self.output(), "")["passed"])

    def test_truncated(self):
        self.assertFalse(driver.validate(0, driver.CASE_PREFIX + driver.EXPECTED_CASES[0], "")["passed"])

    def test_duplicate_summary(self):
        self.assertFalse(driver.validate(0, self.output() * 2, "")["passed"])

    def test_missing_case(self):
        self.assertFalse(driver.validate(0, self.output().replace(driver.CASE_PREFIX + "dead_both\n", ""), "")["passed"])

    def test_zero_checks(self):
        self.assertFalse(driver.validate(0, self.output(checks=0), "")["passed"])

    def test_failed_assertion(self):
        self.assertFalse(driver.validate(0, self.output(failures=1), "")["passed"])

    def test_wrong_engine(self):
        self.assertFalse(driver.validate(0, self.output(engine="4.5.stable"), "")["passed"])

    def test_pack_rejects_source_directory(self):
        with tempfile.TemporaryDirectory() as root:
            project = Path(root) / "project"; project.mkdir()
            (project / "scripts").mkdir()
            self.assertIsNotNone(driver.pack_project_error(project, Path(root) / "out"))

    def test_pack_rejects_nested_output(self):
        with tempfile.TemporaryDirectory() as root:
            self.assertIsNotNone(driver.pack_project_error(Path(root), Path(root) / "out"))

    def test_pack_accepts_empty_project(self):
        with tempfile.TemporaryDirectory() as root:
            project = Path(root) / "project"; project.mkdir()
            self.assertIsNone(driver.pack_project_error(project, Path(root) / "out"))


if __name__ == "__main__":
    unittest.main()
