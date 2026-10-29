"""Portable PTY transport tests; no game or GUI input is exercised."""
import errno
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from native_input_pty import OwnedPTYLog


@unittest.skipUnless(hasattr(os,'openpty'),'POSIX PTY required; no Windows transport change')
class OwnedPTYLogTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / "output.log"

    def child(self, code, fd):
        return subprocess.Popen([sys.executable, "-c", code], stdin=subprocess.DEVNULL,
                                stdout=fd, stderr=fd, close_fds=True)

    def test_live_unflushed_line_and_eof(self):
        log = OwnedPTYLog(self.path)
        with log as fd:
            child = self.child("import time; print('READY'); time.sleep(1)", fd)
            try:
                log.started()
                deadline = time.monotonic() + 0.8
                while time.monotonic() < deadline and b"READY" not in self.path.read_bytes():
                    time.sleep(0.01)
                self.assertIn(b"READY", self.path.read_bytes())
                self.assertIsNone(child.poll())  # Observed before exit, without explicit flush.
                child.wait(timeout=2)
            finally:
                if child.poll() is None:
                    child.kill(); child.wait()
        log.check()
        self.assertIsNone(log.master_fd)
        self.assertIsNone(log.slave_fd)

    def test_oversize_retains_prefix_and_drains(self):
        log = OwnedPTYLog(self.path, budget=100)
        with self.assertRaisesRegex(RuntimeError, "overflow"):
            with log as fd:
                child = self.child("import os; os.write(1,b'x'*200000)", fd)
                log.started()
                child.wait(timeout=3)
        self.assertTrue(log.overflow)
        self.assertEqual(self.path.read_bytes(), b"x"*100)
        self.assertIsNone(log.master_fd)

    def test_popen_failure_closes_all_owned_fds(self):
        log = OwnedPTYLog(self.path)
        with self.assertRaises(FileNotFoundError):
            with log as fd:
                master = log.master_fd
                subprocess.Popen([str(Path(self.temp.name)/"not-an-executable")], stdout=fd, stderr=fd)
        for old in [fd, master]:
            with self.assertRaises(OSError):
                os.fstat(old)

    def test_openpty_failure_closes_log(self):
        log = OwnedPTYLog(self.path)
        with mock.patch("native_input_pty.os.openpty", side_effect=OSError(errno.EMFILE, "test")):
            with self.assertRaises(OSError):
                log.__enter__()
        self.assertIsNone(log._stream)
        self.assertIsNone(log.master_fd)

    def test_nonblocking_setup_failure_closes_fds(self):
        log = OwnedPTYLog(self.path)
        with mock.patch("native_input_pty.os.set_blocking", side_effect=OSError(errno.EINVAL, "test")):
            with self.assertRaises(OSError):
                log.__enter__()
        self.assertIsNone(log.master_fd)
        self.assertIsNone(log.slave_fd)
        self.assertIsNone(log._stream)

    def test_eof_and_eio_normal_other_errors_reported(self):
        for outcome in [b"", OSError(errno.EIO, "EOF"), OSError(errno.EBADF, "bad")]:
            path = self.path.with_name("case-%d.log" % (0 if outcome == b"" else outcome.errno))
            log = OwnedPTYLog(path)
            log.__enter__()
            with mock.patch("native_input_pty.select.select", return_value=([log.master_fd], [], [])):
                with mock.patch("native_input_pty.os.read", side_effect=outcome if isinstance(outcome, OSError) else None,
                                return_value=outcome if isinstance(outcome, bytes) else b""):
                    log._drain()
            log.close()
            if isinstance(outcome, OSError) and outcome.errno == errno.EBADF:
                with self.assertRaisesRegex(RuntimeError, "capture error"):
                    log.check()
            else:
                log.check()

    def test_thread_start_failure_closes_owned_resources(self):
        log = OwnedPTYLog(self.path)
        log.__enter__()
        master, slave = log.master_fd, log.slave_fd
        with mock.patch("native_input_pty.threading.Thread.start", side_effect=RuntimeError("thread unavailable")):
            with self.assertRaisesRegex(RuntimeError, "thread unavailable"):
                log.started()
        self.assertIsNone(log._stream)
        for old in (master, slave):
            with self.assertRaises(OSError):
                os.fstat(old)

    def test_start_failure_cleanup_callback_error_is_not_swallowed(self):
        log = OwnedPTYLog(self.path)
        log.__enter__()
        def failed_cleanup():
            raise RuntimeError("owned cleanup failed")
        with mock.patch("native_input_pty.threading.Thread.start", side_effect=RuntimeError("thread unavailable")):
            with self.assertRaisesRegex(RuntimeError, "owned cleanup failed"):
                log.started(before_error_close=failed_cleanup)
        self.assertIsNone(log.master_fd)
        self.assertIsNone(log.slave_fd)
        self.assertIsNone(log._stream)

    def test_write_failure_is_reported_and_further_bytes_discarded(self):
        log = OwnedPTYLog(self.path, budget=100)
        log.__enter__()
        original = log._stream
        failed_stream = mock.Mock()
        failed_stream.write.side_effect = OSError("disk unavailable")
        log._stream = failed_stream
        try:
            log._store(b"first")
            log._store(b"later")
            self.assertEqual(failed_stream.write.call_count, 1)
            with self.assertRaisesRegex(RuntimeError, "disk unavailable"):
                log.check()
        finally:
            log.close()
            original.close()

    def test_close_live_child_is_bounded_and_not_silently_complete(self):
        log = OwnedPTYLog(self.path)
        fd = log.__enter__()
        child = self.child("import time; time.sleep(3)", fd)
        try:
            log.started()
            before = time.monotonic()
            log.close()
            self.assertLess(time.monotonic()-before, 0.5)
            with self.assertRaisesRegex(RuntimeError, "incomplete"):
                log.check()
            self.assertIsNone(log.master_fd)
        finally:
            child.kill(); child.wait()


if __name__ == "__main__":
    unittest.main()
