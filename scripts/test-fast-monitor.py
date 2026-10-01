#!/usr/bin/env python3
"""Regression: disappearing compiler files must not abandon monitored jobs."""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import Mock, patch

spec=importlib.util.spec_from_file_location('fast_monitor',Path(__file__).with_name('run-bounded-fast.py'))
monitor=importlib.util.module_from_spec(spec);spec.loader.exec_module(monitor)

class DiskMonitorTests(unittest.TestCase):
    def test_du_race_uses_returned_aggregate(self):
        result=subprocess.CompletedProcess([],1,'1234 /build\n','du: vanished .tmp file\n')
        with patch.object(monitor.subprocess,'run',return_value=result):
            self.assertEqual(monitor.allocated_bytes(Path('/build')),1234*1024)
    def test_no_aggregate_fails(self):
        result=subprocess.CompletedProcess([],1,'','du: filesystem unavailable\n')
        with patch.object(monitor.subprocess,'run',return_value=result):
            with self.assertRaises(RuntimeError):monitor.allocated_bytes(Path('/build'))
    def test_unexpected_error_stops_owned_job_and_records_failure(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);(root/'build/fast-source').mkdir(parents=True)
            process=Mock();process.poll.return_value=None;process.wait.return_value=-15
            with patch.object(monitor,'free_bytes',return_value=38*1024**3),patch.object(monitor,'allocated_bytes',side_effect=RuntimeError('test outage')),patch.object(monitor.subprocess,'Popen',return_value=process),patch.object(monitor,'stop_owned_job') as stop:
                self.assertEqual(monitor.run_stage('failure',['owned-test-job'],root),1)
                stop.assert_called_once_with(process)
            report=json.loads((root/'build/evidence/failure-resource.json').read_text())
            self.assertIn('Supervisor failure',report['stopped_reason'])
    def test_floor_stop_persists_sample_and_stops_owned_job(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);(root/'build/fast-source').mkdir(parents=True)
            process=Mock();process.poll.return_value=None;process.wait.return_value=-15
            with patch.object(monitor,'free_bytes',side_effect=[38*1024**3,38*1024**3,38*1024**3,31*1024**3]),patch.object(monitor,'allocated_bytes',return_value=1024),patch.object(monitor.subprocess,'Popen',return_value=process),patch.object(monitor,'stop_owned_job') as stop:
                self.assertEqual(monitor.run_stage('floor',['owned-test-job'],root),1)
                stop.assert_called_once_with(process)
            self.assertTrue((root/'build/evidence/floor.disk.jsonl').read_text())

if __name__=='__main__':unittest.main()
