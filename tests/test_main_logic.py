import unittest
import shutil
import uuid
from pathlib import Path
from unittest.mock import patch, MagicMock

from agents import artifacts, main, models
from governance import gate, audit_log, report
from agents.main import _extract_action_from_text
from agents.schemas import parse_remediation


class MainLogicTests(unittest.TestCase):
    def test_parse_remediation_prefers_tool_field(self):
        plan = parse_remediation('{"tool": "restart_pods", "parameters": {"service_name": "api"}}')
        self.assertEqual(plan.to_action_dict(), {"tool": "restart_pods", "parameters": {"service_name": "api"}})

    def test_extract_action_from_json_text(self):
        action = _extract_action_from_text(
            '{"action_taken":"scale_deployment","parameters":{"service_name":"checkout","target_replicas":4}}'
        )
        self.assertEqual(action["tool"], "scale_deployment")
        self.assertEqual(action["parameters"]["target_replicas"], 4)

    def test_extract_action_from_embedded_json_preserves_parameters(self):
        action = _extract_action_from_text(
            'Recommended action: {"action_taken":"rollback_deployment","parameters":{"service_name":"checkout"}}'
        )
        self.assertEqual(
            action,
            {"tool": "rollback_deployment", "parameters": {"service_name": "checkout"}},
        )

    def test_extract_action_defaults_to_noop_when_missing(self):
        action = _extract_action_from_text("no remediation proposed")
        self.assertEqual(action, {"tool": "noop_require_human", "parameters": {}})

    def test_parse_remediation_rejects_unknown_tool(self):
        plan = parse_remediation('{"action_taken": "delete_cluster", "parameters": {"service_name": "api"}}')
        self.assertEqual(plan.action_taken, "noop_require_human")


class ModelsLogicTests(unittest.TestCase):
    def test_get_model_returns_mock_model_in_mock_mode(self):
        with patch.dict("os.environ", {"NOVAOPS_USE_MOCK": "1"}, clear=False):
            model = models.get_model("LOW")

        self.assertIsInstance(model, models.MockModel)
        self.assertEqual(model.thinking_tier, "LOW")

    def test_get_model_uses_bedrock_model_outside_mock_mode(self):
        with patch.dict("os.environ", {"NOVAOPS_USE_MOCK": "0", "LOCAL_EVAL_MODE": "0"}, clear=False):
            with patch.object(models, "BedrockModel", autospec=True) as bedrock_model:
                sentinel = object()
                bedrock_model.return_value = sentinel
                model = models.get_model("MEDIUM", temperature=0.4)

        self.assertIs(model, sentinel)
        bedrock_model.assert_called_once()


if __name__ == "__main__":
    unittest.main()
