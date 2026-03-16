import unittest
import os
import shutil
import uuid
from pathlib import Path
from unittest.mock import patch

from agents import artifacts, main
from governance import gate, audit_log, report

class IntegrationTests(unittest.TestCase):
    def setUp(self):
        self.base_dir = Path("tests/.tmp_integration")
        self.base_dir.mkdir(parents=True, exist_ok=True)
        self.temp_dir = self.base_dir / uuid.uuid4().hex
        
        # Patch artifact directories to use temp path
        self.patchers = [
            patch.object(artifacts, "PLANS_DIR", self.temp_dir),
            patch.object(gate, "PLANS_DIR", self.temp_dir),
            patch.object(audit_log, "PLANS_DIR", self.temp_dir),
            patch.object(report, "PLANS_DIR", self.temp_dir)
        ]
        for p in self.patchers:
            p.start()

    def tearDown(self):
        for p in self.patchers:
            p.stop()
        if self.base_dir.exists():
            shutil.rmtree(self.base_dir, ignore_errors=True)

    def test_run_completes_end_to_end_in_mock_mode(self):
        """Full pipeline integration test in mock mode."""
        with patch.dict("os.environ", {"NOVAOPS_USE_MOCK": "1"}, clear=False):
            result = main.run("P2 traffic surge alert on checkout-service in prod causing elevated latency")

        self.assertEqual(result["domain"], "traffic_surge")
        self.assertEqual(result["proposed_action"]["tool"], "scale_deployment")
        self.assertIn(result["governance_status"], {"auto_executed", "pending_approval"})

        incident_dir = self.temp_dir / result["incident_id"]
        self.assertTrue((incident_dir / "report.md").exists())
        self.assertTrue((incident_dir / "governance.json").exists())
        self.assertTrue((incident_dir / "governance_report.md").exists())

    def test_run_unknown_alert_stays_human_gated(self):
        """Full pipeline test for unknown alert ensuring human gating."""
        with patch.dict("os.environ", {"NOVAOPS_USE_MOCK": "1"}, clear=False):
            result = main.run("Intermittent anomaly observed on checkout-service with unclear symptoms")

        self.assertEqual(result["domain"], "unknown")
        self.assertEqual(result["proposed_action"]["tool"], "noop_require_human")
        self.assertEqual(result["governance_decision"], "REQUIRE_APPROVAL")
        self.assertEqual(result["governance_status"], "pending_approval")

if __name__ == "__main__":
    unittest.main()
