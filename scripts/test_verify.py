"""Check verifier failures without Pharo or account access."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import verify


class VerificationTest(unittest.TestCase):
    def test_missing_base_reports_configuration_error(self):
        env = dict(os.environ)
        env.pop('SMALLGPTALK_BASE_IMAGE', None)
        result = subprocess.run([sys.executable, str(verify.ROOT / 'scripts/verify.py')],
                                env=env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn('Set SMALLGPTALK_BASE_IMAGE', result.stderr)
        self.assertNotIn('Traceback', result.stderr)

    def test_missing_changes_reports_the_file(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory) / 'Pharo.image'
            base.touch()
            result = subprocess.run(
                [sys.executable, str(verify.ROOT / 'scripts/verify.py')],
                env=dict(os.environ, SMALLGPTALK_BASE_IMAGE=str(base)),
                capture_output=True, text=True)
            self.assertEqual(result.returncode, 2)
            self.assertIn(str(base.with_suffix('.changes')), result.stderr)
            self.assertNotIn('Traceback', result.stderr)

    def test_check_writes_only_in_its_work_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / 'check.log'
            code = 'from pathlib import Path; print(Path.cwd())'
            verify.run([sys.executable, '-c', code], log, dict(os.environ))
            self.assertEqual(Path(log.read_text().strip()), Path(directory).resolve())

    def test_failed_check_keeps_output_and_reports_log(self):
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / 'check.log'
            with self.assertRaisesRegex(RuntimeError, 'Check failed') as failure:
                verify.run([sys.executable, '-c', 'print("diagnostic"); exit(7)'],
                           log, dict(os.environ))
            self.assertIn(str(log), str(failure.exception))
            self.assertIn('diagnostic', log.read_text())

    def test_timeout_reaps_process_and_reports_log(self):
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / 'check.log'
            code = 'import os, time; print(os.getpid(), flush=True); time.sleep(60)'
            with self.assertRaisesRegex(RuntimeError, 'Check timed out') as failure:
                verify.run([sys.executable, '-c', code], log, dict(os.environ), timeout=1)
            self.assertIn(str(log), str(failure.exception))
            pid = int(log.read_text().strip())
            with self.assertRaises(ProcessLookupError):
                os.kill(pid, 0)


if __name__ == '__main__':
    unittest.main()
