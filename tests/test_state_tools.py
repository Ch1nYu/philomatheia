from __future__ import annotations

import copy
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def load_validator():
    path = ROOT / "scripts" / "validate_state.py"
    spec = importlib.util.spec_from_file_location("philomatheia_validate_state", path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


validator = load_validator()


def active_state() -> dict:
    timestamp = "2026-09-02T00:00:00+00:00"
    source = {
        "id": "src-1",
        "type": "primary",
        "title": "Source",
        "locator": "https://example.com/source",
        "publisher_or_author": "Example",
        "accessed_at": timestamp,
        "version": "1",
        "supports": ["node-1"],
        "conflicts": [],
        "limits": "Fixture source",
    }
    evidence = {
        "id": "ev-1",
        "at": timestamp,
        "session_id": "session-1",
        "kind": "recall",
        "result": "pass",
        "demonstrated_level": 1,
        "independent": True,
        "hints_used": 0,
        "artifact": None,
        "artifact_verified": False,
        "notes": "Recalled the idea",
        "source_ids": ["src-1"],
    }
    data = {
        "schema_version": "philomatheia.learning-state/0.1",
        "project": {
            "id": "fixture",
            "title": "Fixture",
            "domain": "general",
            "language": "en",
            "status": "active",
            "auto_commit": False,
            "created_at": timestamp,
            "updated_at": timestamp,
        },
        "goal": {
            "statement": "Demonstrate node 1",
            "status": "active",
            "target_node_ids": ["node-1"],
            "completion_contract": {
                "description": "Complete an integrative task",
                "status": "pending",
                "evidence_id": None,
            },
        },
        "graph": {
            "map_version": 1,
            "nodes": [
                {
                    "id": "node-1",
                    "title": "Node 1",
                    "kind": "concept",
                    "source_ids": ["src-1"],
                    "learning": {
                        "current_level": 1,
                        "highest_level": 1,
                        "confidence": 0.5,
                        "evidence": [evidence],
                        "error_patterns": [],
                        "last_seen": timestamp,
                        "next_review": None,
                    },
                }
            ],
            "edges": [],
        },
        "goal_subgraph": {
            "revision": 1,
            "user_approved_revision": 1,
            "approved_fingerprint": None,
            "nodes": [
                {"node_id": "node-1", "required": True, "target_level": 1, "goal_weight": 1.0}
            ],
        },
        "planner": {
            "strategy": "goal_weighted_spiral_bfs",
            "pass": 1,
            "pass_target_level": 1,
            "frontier": [{"node_id": "node-1", "score": 1.0, "reasons": ["goal"]}],
            "inserted_review_node_id": None,
        },
        "sources": [source],
        "checkpoint": {
            "status": "active",
            "session_id": "session-1",
            "saved_at": timestamp,
            "map_version": 1,
            "active_node_id": "node-1",
            "phase": "recall",
            "last_completed_action": "Recorded baseline recall",
            "pending_question": None,
            "resume_summary": "Baseline recall passed",
            "verified": ["state"],
            "blockers": [],
            "new_evidence_ids": ["ev-1"],
            "mastery_changes": ["node-1: 0 -> 1"],
            "load_response": None,
            "pending_major_route_proposal": None,
            "next_action": "Ask one explanation question",
            "open_artifacts": [],
        },
        "session_log": [],
    }
    data["goal_subgraph"]["approved_fingerprint"] = validator.route_approval_fingerprint(data)
    return data


class StateToolTests(unittest.TestCase):
    def test_initializer_creates_valid_planning_state_and_preserves_it(self):
        with tempfile.TemporaryDirectory() as directory:
            command = [
                sys.executable,
                str(ROOT / "scripts" / "init_project.py"),
                "--root",
                directory,
                "--title",
                "統計學",
                "--goal",
                "Read research critically",
            ]
            created = subprocess.run(command, check=False, capture_output=True, text=True)
            self.assertEqual(created.returncode, 0, created.stderr)
            payload = json.loads(created.stdout)
            state_path = Path(payload["state"])
            self.assertTrue(state_path.exists())
            state = json.loads(state_path.read_text(encoding="utf-8"))
            self.assertRegex(state["project"]["id"], r"^learning-project-[0-9a-f]{8}$")
            errors, _warnings = validator.validate(state)
            self.assertEqual(errors, [])

            repeated = subprocess.run(command, check=False, capture_output=True, text=True)
            self.assertEqual(repeated.returncode, 2)
            self.assertEqual(json.loads(repeated.stdout)["error"], "state_exists")

    def test_active_fixture_is_valid(self):
        errors, warnings = validator.validate(active_state())
        self.assertEqual(errors, [])
        self.assertEqual(len(warnings), 1)

    def test_heavy_hints_cannot_prove_independent_level_four(self):
        data = active_state()
        learning = data["graph"]["nodes"][0]["learning"]
        learning["current_level"] = 4
        learning["highest_level"] = 4
        evidence = learning["evidence"][0]
        evidence["demonstrated_level"] = 4
        evidence["hints_used"] = 3
        errors, _warnings = validator.validate(data)
        self.assertTrue(any("requires independent passing evidence with zero hints" in error for error in errors))

    def test_provenance_is_required_for_active_nodes(self):
        data = active_state()
        data["graph"]["nodes"][0]["source_ids"] = []
        errors, _warnings = validator.validate(data)
        self.assertTrue(any("provenance source" in error for error in errors))

    def test_ephemeral_checkpoint_locator_is_rejected(self):
        data = active_state()
        data["checkpoint"]["status"] = "awaiting_learner_response"
        data["checkpoint"]["pending_question"] = "conversation:turn-42"
        errors, _warnings = validator.validate(data)
        self.assertTrue(any("ephemeral locator" in error for error in errors))

    def test_route_fingerprint_ignores_runtime_completion_fields(self):
        first = active_state()
        second = copy.deepcopy(first)
        second["goal"]["completion_contract"]["status"] = "passed"
        second["goal"]["completion_contract"]["evidence_id"] = "ev-other"
        self.assertEqual(
            validator.route_approval_fingerprint(first),
            validator.route_approval_fingerprint(second),
        )

    def test_artifact_paths_stay_project_relative(self):
        self.assertTrue(validator.safe_relative_path(".philomatheia/artifacts/work.py"))
        self.assertFalse(validator.safe_relative_path("../private.txt"))
        self.assertFalse(validator.safe_relative_path("C:\\Windows\\System32"))


if __name__ == "__main__":
    unittest.main()
