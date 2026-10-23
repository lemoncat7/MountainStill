#!/usr/bin/env python3
"""Driver output regression; runnable without Godot or a Windows host."""
import io
import sys
import unittest
from unittest.mock import patch

import native_platform_smoke as smoke


class OutputEncodingTests(unittest.TestCase):
    def test_narrow_windows_streams_preserve_utf8_and_error_detection(self):
        stdout_bytes, stderr_bytes = io.BytesIO(), io.BytesIO()
        stdout = io.TextIOWrapper(stdout_bytes, encoding='cp1252', errors='strict', newline='\n')
        stderr = io.TextIOWrapper(stderr_bytes, encoding='cp1252', errors='strict', newline='\n')
        diagnostic = 'ERROR: 山隐测试报错\n'
        payload = repr(diagnostic.encode('utf-8'))
        with patch.object(sys, 'stdout', stdout), patch.object(sys, 'stderr', stderr):
            smoke.configure_output()
            code, captured = smoke.run(
                [sys.executable, '-c', f'import sys; sys.stdout.buffer.write({payload})'], 10)
            print('stderr 中文', file=sys.stderr, flush=True)
        self.assertEqual(code, 0)
        self.assertEqual(captured, diagnostic)
        self.assertEqual(stdout_bytes.getvalue().decode('utf-8'), diagnostic)
        self.assertEqual(stderr_bytes.getvalue().decode('utf-8'), 'stderr 中文\n')
        self.assertEqual(smoke.unexpected_errors(captured, 'test_cultivation.gd'),
                         [diagnostic.strip()])
        stdout.close()
        stderr.close()


if __name__ == '__main__':
    unittest.main()
