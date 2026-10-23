#!/usr/bin/env python3
"""Read-only metrics for a caller-owned live child; no admin rights/dependencies.

The orchestrator must pass its own Popen.pid, check poll() before/after sampling,
retain the initial identity and reject changes. This module never discovers or
attaches to arbitrary processes by name. Missing metrics raise, never become zero.
RSS is Windows working-set bytes or macOS ps RSS bytes, not private retained bytes.
"""
import ctypes
from datetime import datetime
import math
import os
import re
import subprocess
import sys


def _pid(value):
    if isinstance(value, bool) or not isinstance(value, int) or not 0 < value <= 0xffffffff:
        raise ValueError('Expected a positive caller-owned child PID')
    return value


def parse_cpu_time(value):
    """Parse ps cumulative CPU: MM:SS[.fraction], HH:MM:SS, or D-HH:MM:SS."""
    match = re.fullmatch(r'(?:(\d+)-)?(\d+):(\d{2})(?::(\d{2}))?(\.\d+)?', value)
    if not match:
        raise ValueError('Invalid cumulative CPU time: ' + repr(value))
    days, first, second, third, fraction = match.groups()
    if days is not None and third is None:
        raise ValueError('Day-prefixed CPU time requires hours/minutes/seconds')
    if third is None:
        hours, minutes, seconds = 0, int(first), int(second)
    else:
        hours, minutes, seconds = int(first), int(second), int(third)
        if minutes >= 60 or (days is not None and hours >= 24):
            raise ValueError('Out-of-range CPU time component')
    if seconds >= 60:
        raise ValueError('Out-of-range CPU seconds')
    total = (int(days or 0) * 86400 + hours * 3600 + minutes * 60 + seconds
             + float('0' + (fraction or '')))
    if not math.isfinite(total):
        raise ValueError('Non-finite cumulative CPU time')
    return total


def parse_macos_ps(output, expected_pid):
    expected_pid = _pid(expected_pid)
    lines = [line.strip() for line in output.splitlines() if line.strip()]
    if len(lines) != 1:
        raise ValueError('Expected exactly one live process metrics row')
    match = re.fullmatch(
        r'(\d+)\s+((?:Mon|Tue|Wed|Thu|Fri|Sat|Sun)\s+'
        r'(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+'
        r'\d{1,2}\s+\d{2}:\d{2}:\d{2}\s+\d{4})\s+(\d+)\s+(\S+)', lines[0])
    if not match or int(match[1]) != expected_pid:
        raise ValueError('Missing/mismatched PID or malformed macOS metrics row')
    started = ' '.join(match[2].split())
    weekday, month, day, clock, year = started.split()
    months = 'Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec'.split()
    hour, minute, second = map(int, clock.split(':'))
    stamp = datetime(int(year), months.index(month) + 1, int(day), hour, minute, second)
    if ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][stamp.weekday()] != weekday:
        raise ValueError('Invalid process start weekday/date')
    rss = int(match[3]) * 1024
    if rss <= 0:
        raise ValueError('Live process RSS missing or zero')
    return {'pid': expected_pid, 'cpu_seconds': parse_cpu_time(match[4]),
            'rss_bytes': rss, 'identity': f'macos:{expected_pid}:{started}',
            'nativefieldtype': 'macos_ps_rss_kib_to_bytes_and_cumulative_cpu_time'}


def _sample_windows(pid):
    # Explicit 32-bit DWORD/64-bit FILETIME halves avoid host C long ambiguity.
    DWORD = ctypes.c_uint32
    HANDLE = ctypes.c_void_p
    SIZE_T = ctypes.c_size_t

    class FILETIME(ctypes.Structure):
        _fields_ = [('low', DWORD), ('high', DWORD)]

    class MEMORY(ctypes.Structure):
        _fields_ = [('cb', DWORD), ('PageFaultCount', DWORD)] + [
            (name, SIZE_T) for name in ('PeakWorkingSetSize', 'WorkingSetSize',
            'QuotaPeakPagedPoolUsage', 'QuotaPagedPoolUsage',
            'QuotaPeakNonPagedPoolUsage', 'QuotaNonPagedPoolUsage',
            'PagefileUsage', 'PeakPagefileUsage')]

    kernel = ctypes.WinDLL('kernel32', use_last_error=True)
    kernel.OpenProcess.argtypes = [DWORD, ctypes.c_int, DWORD]
    kernel.OpenProcess.restype = HANDLE
    kernel.CloseHandle.argtypes = [HANDLE]
    kernel.CloseHandle.restype = ctypes.c_int
    kernel.WaitForSingleObject.argtypes = [HANDLE, DWORD]
    kernel.WaitForSingleObject.restype = DWORD
    kernel.GetProcessTimes.argtypes = [HANDLE] + [ctypes.POINTER(FILETIME)] * 4
    kernel.GetProcessTimes.restype = ctypes.c_int
    kernel.K32GetProcessMemoryInfo.argtypes = [HANDLE, ctypes.POINTER(MEMORY), DWORD]
    kernel.K32GetProcessMemoryInfo.restype = ctypes.c_int
    handle = kernel.OpenProcess(0x1000 | 0x100000, False, pid)  # QUERY_LIMITED_INFORMATION + SYNCHRONIZE
    if not handle:
        raise ctypes.WinError(ctypes.get_last_error())
    try:
        created, exited, kernel_time, user_time = (FILETIME() for _ in range(4))
        if not kernel.GetProcessTimes(handle, ctypes.byref(created), ctypes.byref(exited),
                                      ctypes.byref(kernel_time), ctypes.byref(user_time)):
            raise ctypes.WinError(ctypes.get_last_error())
        ticks = lambda value: (value.high << 32) | value.low
        # GetProcessTimes exit FILETIME is undefined for a live process.
        # A zero-time handle wait distinguishes live from exited without using it.
        if kernel.WaitForSingleObject(handle, 0) != 258:  # WAIT_TIMEOUT means live
            raise RuntimeError('Owned child exited or handle wait failed during sampling')
        memory = MEMORY()
        memory.cb = ctypes.sizeof(memory)
        if not kernel.K32GetProcessMemoryInfo(handle, ctypes.byref(memory), memory.cb):
            raise ctypes.WinError(ctypes.get_last_error())
        if memory.WorkingSetSize <= 0 or ticks(created) <= 0:
            raise RuntimeError('Missing live process memory/creation identity')
        if kernel.WaitForSingleObject(handle, 0) != 258:
            raise RuntimeError('Owned child exited or handle wait failed during sampling')
        return {'pid': pid, 'cpu_seconds': (ticks(kernel_time) + ticks(user_time)) / 10_000_000,
                'rss_bytes': int(memory.WorkingSetSize),
                'identity': f'windows:{pid}:{ticks(created)}',
                'nativefieldtype': 'windows_working_set_bytes_and_kernel_plus_user_cpu'}
    finally:
        if not kernel.CloseHandle(handle):
            raise ctypes.WinError(ctypes.get_last_error())


def sample(pid):
    """Sample ONLY the caller's owned Popen child. Caller must validate identity."""
    pid = _pid(pid)
    if sys.platform == 'win32':
        return _sample_windows(pid)
    if sys.platform == 'darwin':
        environment = os.environ.copy()
        environment.update(LC_ALL='C', LANG='C')
        output = subprocess.run(['/bin/ps', '-p', str(pid), '-o', 'pid=,lstart=,rss=,time='],
                                check=True, capture_output=True, text=True,
                                encoding='utf-8', errors='strict', env=environment,
                                timeout=5).stdout
        return parse_macos_ps(output, pid)
    raise RuntimeError('Native Windows/macOS metrics only; unsupported platform')


def cpu_percent(previous, current, wall_seconds):
    """Single-core-equivalent percentage; >100 is valid for multithreaded work."""
    if (not previous.get('identity') or current.get('identity') != previous['identity']
            or _pid(previous.get('pid')) != _pid(current.get('pid'))
            or not previous.get('nativefieldtype')
            or current.get('nativefieldtype') != previous['nativefieldtype']):
        raise ValueError('Process identity or native measurement type changed/missing')
    values = (previous.get('cpu_seconds'), current.get('cpu_seconds'), wall_seconds)
    if any(isinstance(v, bool) or not isinstance(v, (int, float)) or not math.isfinite(v) for v in values):
        raise ValueError('CPU/wall times must be finite numbers')
    before, after, elapsed = values
    if before < 0 or after < before or elapsed <= 0:
        raise ValueError('Non-monotonic CPU counter or invalid observation interval')
    return 100 * (after - before) / elapsed
