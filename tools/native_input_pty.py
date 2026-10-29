"""Owned, bounded PTY output capture; never sends input to the child terminal."""
from __future__ import annotations

import errno
import os
from pathlib import Path
import select
import threading


class OwnedPTYLog:
    """Use ``with log as slave_fd``, Popen stdout/stderr=slave_fd, then started().

    Stop the owned child before leaving the context. check() raises on overflow or
    capture errors: a prefix-only log must never be accepted as complete evidence.
    """

    def __init__(self, path, budget=4 * 1024 * 1024):
        if not isinstance(budget, int) or isinstance(budget, bool) or budget <= 0:
            raise ValueError("PTY log budget must be a positive integer")
        self.path = Path(path)
        self.budget = budget
        self.slave_fd = None
        self.master_fd = None
        self.error = None
        self.overflow = False
        self.bytes_written = 0
        self._stream = None
        self._thread = None
        self._stop = threading.Event()
        self._entered = False
        self._closed = False

    def __enter__(self):
        if self._entered or self._closed:
            raise RuntimeError("OwnedPTYLog is single-use")
        self._entered = True
        try:
            self._stream = self.path.open("xb")
            self.master_fd, self.slave_fd = os.openpty()
            os.set_blocking(self.master_fd, False)
            return self.slave_fd
        except BaseException:
            self.close()
            raise

    def started(self, before_error_close=None):
        """Call immediately after Popen succeeds; the child owns its slave copy.

        before_error_close, if supplied, stops/reaps the child before cleanup
        when thread startup fails. Cleanup errors propagate, never become evidence.
        """
        if not self._entered or self._closed or self._thread is not None:
            raise RuntimeError("PTY capture is not awaiting a child")
        self._close_fd("slave_fd")
        self._thread = threading.Thread(target=self._drain, name="owned-pty-log", daemon=True)
        try:
            self._thread.start()
        except BaseException:
            self._thread = None
            try:
                if before_error_close is not None:
                    before_error_close()
            finally:
                self.close()
            raise

    def _record_error(self, error):
        if self.error is None:
            self.error = str(error)

    def _store(self, chunk):
        available = self.budget - self.bytes_written
        if len(chunk) > available:
            self.overflow = True
        prefix = chunk[:max(0, available)]
        if prefix and self._stream is not None:
            try:
                self._stream.write(prefix)
                self._stream.flush()  # Live readiness reader must see each chunk.
                self.bytes_written += len(prefix)
            except Exception as exc:
                self._record_error(exc)
                # Continue draining/discarding so a child cannot block on output.
                self.bytes_written = self.budget

    def _drain(self):
        # This worker exclusively owns reads until joined; close never closes its
        # descriptor underneath a running read/select (avoids fd-reuse races).
        fd = self.master_fd
        try:
            while not self._stop.is_set():
                try:
                    ready, _, _ = select.select([fd], [], [], 0.025)
                    if not ready:
                        continue
                    chunk = os.read(fd, 65536)
                    if not chunk:
                        return
                    self._store(chunk)
                except OSError as exc:
                    if exc.errno == errno.EIO:  # PTY EOF on Linux/macOS.
                        return
                    if exc.errno in (errno.EAGAIN, errno.EWOULDBLOCK, errno.EINTR):
                        continue
                    self._record_error(exc)
                    return
        except Exception as exc:
            self._record_error(exc)
        finally:
            # Worker closes only after its final read; even a delayed worker
            # eventually releases its descriptors without an fd-reuse race.
            self._finish_resources()

    def check(self):
        if self.error is not None:
            raise RuntimeError("PTY capture error: " + self.error)
        if self.overflow:
            raise RuntimeError("PTY capture overflow: log contains only the first %d bytes" % self.budget)

    def _close_fd(self, attribute):
        fd = getattr(self, attribute)
        if fd is not None:
            setattr(self, attribute, None)
            try:
                os.close(fd)
            except OSError as exc:
                self._record_error(exc)

    def close(self):
        if self._closed:
            return
        self._closed = True
        self._close_fd("slave_fd")
        thread = self._thread
        if thread is not None:
            # First allow terminal EOF to drain pending output after child exit.
            thread.join(0.2)
            if thread.is_alive():
                self._record_error("PTY capture stopped before terminal EOF; log may be incomplete")
            self._stop.set()
            thread.join(0.2)
            if thread.is_alive():
                # Never close/reuse a descriptor still touched by the worker.
                # Owned regular log writes should not stall; report rather than
                # blocking teardown or silently treating evidence as complete.
                self._record_error("PTY drain did not stop within bounded close")
                return
        self._stop.set()
        self._finish_resources()

    def _finish_resources(self):
        self._close_fd("master_fd")
        if self._stream is not None:
            stream, self._stream = self._stream, None
            try:
                stream.close()
            except Exception as exc:
                self._record_error(exc)

    def __exit__(self, exc_type, exc_value, traceback):
        self.close()
        if exc_type is None:
            self.check()
        return False
