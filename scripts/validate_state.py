#!/usr/bin/env python3
"""Validate Philomatheia state invariants and emit a JSON result."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from datetime import datetime
from pathlib import Path, PurePosixPath, PureWindowsPath
from typing import Any


SCHEMA_VERSION = "philomatheia.learning-state/0.1"
NODE_KINDS = {"concept", "skill", "procedure", "fact", "strategy", "integration"}
EDGE_TYPES = {"prerequisite", "part_of", "contrasts", "applies_to", "analogous_to"}
LOOP_PHASES = {"orient", "recall", "explain", "practice", "verify", "integrate"}
PASS_RESULTS = {"pass", "partial", "fail"}
PROJECT_STATUSES = {"planning", "active", "paused", "complete", "blocked"}
CHECKPOINT_STATUSES = {"planning", "active", "awaiting_learner_response", "paused", "complete", "blocked"}
LEVEL_FIVE_EVIDENCE_KINDS = {
    "transfer",
    "novel_transfer",
    "cross_context_application",
    "debugging_transfer",
    "teach_back_transfer",
    "integrative_transfer",
    "capstone_transfer",
}
INTEGRATIVE_EVIDENCE_KINDS = {
    "integration",
    "integrative_task",
    "integrative_project",
    "capstone",
    "capstone_project",
    "integrative_transfer",
    "capstone_transfer",
}
EPHEMERAL_LOCATOR = re.compile(
    r"^\s*(?:conversation|chat|thread|codex|session)(?::|://)", re.IGNORECASE
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("state", nargs="?", type=Path, default=Path(".philomatheia/learning-state.json"))
    return parser.parse_args()


def valid_timestamp(value: Any) -> bool:
    if not isinstance(value, str):
        return False
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return False
    return parsed.tzinfo is not None


def parse_timestamp(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def safe_relative_path(value: Any) -> bool:
    if not isinstance(value, str) or not value:
        return False
    windows_path = PureWindowsPath(value)
    if value.startswith(("\\\\", "//")) or windows_path.drive or windows_path.is_absolute():
        return False
    path = PurePosixPath(value.replace("\\", "/"))
    return not path.is_absolute() and ".." not in path.parts


def route_approval_fingerprint(data: dict[str, Any]) -> str:
    """Return the canonical fingerprint for the learner-approved route contract."""
    goal = data.get("goal") if isinstance(data.get("goal"), dict) else {}
    subgraph = data.get("goal_subgraph") if isinstance(data.get("goal_subgraph"), dict) else {}
    completion = goal.get("completion_contract")
    if not isinstance(completion, dict):
        completion = {}
    contract = {
        key: value
        for key, value in completion.items()
        if key not in {"status", "evidence_id"}
    }
    raw_nodes = subgraph.get("nodes")
    if not isinstance(raw_nodes, list):
        raw_nodes = []
    normalized_nodes = []
    for item in raw_nodes:
        if not isinstance(item, dict):
            continue
        normalized_nodes.append(
            {
                "node_id": item.get("node_id"),
                "required": item.get("required"),
                "target_level": item.get("target_level"),
                "goal_weight": item.get("goal_weight"),
            }
        )
    raw_targets = goal.get("target_node_ids")
    if not isinstance(raw_targets, list):
        raw_targets = []
    payload = {
        "revision": subgraph.get("revision"),
        "target_node_ids": sorted(raw_targets, key=lambda value: str(value)),
        "nodes": sorted(normalized_nodes, key=lambda item: str(item.get("node_id"))),
        "completion_contract": contract,
    }
    canonical = json.dumps(
        payload,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return "sha256:" + hashlib.sha256(canonical).hexdigest()


def pending_question_is_durable(value: str) -> bool:
    stripped = value.strip()
    if EPHEMERAL_LOCATOR.match(stripped):
        return False
    if stripped.startswith((".philomatheia/", ".philomatheia\\")):
        normalized = stripped.replace("\\", "/")
        return normalized.startswith(".philomatheia/artifacts/") and safe_relative_path(stripped)
    return True


def find_prerequisite_cycle(node_ids: set[str], edges: list[dict[str, Any]]) -> list[str] | None:
    adjacency = {node_id: [] for node_id in node_ids}
    for edge in edges:
        if edge.get("type") == "prerequisite" and edge.get("from") in node_ids and edge.get("to") in node_ids:
            adjacency[edge["from"]].append(edge["to"])

    visiting: set[str] = set()
    visited: set[str] = set()

    def visit(node_id: str, path: list[str]) -> list[str] | None:
        if node_id in visiting:
            start = path.index(node_id)
            return path[start:] + [node_id]
        if node_id in visited:
            return None
        visiting.add(node_id)
        for target in adjacency[node_id]:
            cycle = visit(target, path + [target])
            if cycle:
                return cycle
        visiting.remove(node_id)
        visited.add(node_id)
        return None

    for node_id in node_ids:
        cycle = visit(node_id, [node_id])
        if cycle:
            return cycle
    return None


def prerequisite_closure(targets: list[str], edges: list[dict[str, Any]]) -> set[str]:
    incoming: dict[str, list[str]] = {}
    for edge in edges:
        if edge.get("type") == "prerequisite":
            incoming.setdefault(edge.get("to"), []).append(edge.get("from"))
    closure: set[str] = set()
    stack = list(targets)
    while stack:
        node_id = stack.pop()
        if node_id in closure:
            continue
        closure.add(node_id)
        stack.extend(incoming.get(node_id, []))
    return closure


def validate(data: dict[str, Any]) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []

    if data.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"schema_version must be {SCHEMA_VERSION}")

    project = data.get("project")
    if not isinstance(project, dict):
        errors.append("project must be an object")
        project = {}
    for field in ("id", "title", "domain", "language", "status"):
        if not isinstance(project.get(field), str) or not project.get(field):
            errors.append(f"project.{field} must be a non-empty string")
    if project.get("status") not in PROJECT_STATUSES:
        errors.append("project.status is invalid")
    if not isinstance(project.get("auto_commit"), bool):
        errors.append("project.auto_commit must be boolean")
    for field in ("created_at", "updated_at"):
        if not valid_timestamp(project.get(field)):
            errors.append(f"project.{field} must be an ISO-8601 timestamp with timezone")

    sources = data.get("sources")
    if not isinstance(sources, list):
        errors.append("sources must be an array")
        sources = []
    source_ids: list[str] = []
    for index, source in enumerate(sources):
        prefix = f"sources[{index}]"
        if not isinstance(source, dict):
            errors.append(f"{prefix} must be an object")
            continue
        source_id = source.get("id")
        if not isinstance(source_id, str) or not source_id:
            errors.append(f"{prefix}.id must be a non-empty string")
        else:
            source_ids.append(source_id)
        for field in ("type", "title", "locator"):
            if not isinstance(source.get(field), str) or not source.get(field):
                errors.append(f"{prefix}.{field} must be a non-empty string")
        if not isinstance(source.get("publisher_or_author"), str) or not source.get("publisher_or_author"):
            errors.append(f"{prefix}.publisher_or_author must be a non-empty string")
        if not valid_timestamp(source.get("accessed_at")):
            errors.append(f"{prefix}.accessed_at must be an ISO-8601 timestamp with timezone")
        if "version" in source and not isinstance(source.get("version"), str):
            errors.append(f"{prefix}.version must be a string when present")
        supports = source.get("supports")
        if (
            not isinstance(supports, list)
            or not supports
            or any(not isinstance(claim, str) or not claim.strip() for claim in supports)
        ):
            errors.append(f"{prefix}.supports must be a non-empty array of strings")
        conflicts = source.get("conflicts")
        if not isinstance(conflicts, list) or any(
            not isinstance(conflict, str) or not conflict.strip() for conflict in conflicts
        ):
            errors.append(f"{prefix}.conflicts must be an array of strings")
        if not isinstance(source.get("limits"), str) or not source.get("limits").strip():
            errors.append(f"{prefix}.limits must be a non-empty string")
    if len(source_ids) != len(set(source_ids)):
        errors.append("source ids must be unique")
    source_set = set(source_ids)

    graph = data.get("graph")
    if not isinstance(graph, dict):
        errors.append("graph must be an object")
        graph = {}
    if not isinstance(graph.get("map_version"), int) or isinstance(graph.get("map_version"), bool) or graph.get("map_version", 0) < 1:
        errors.append("graph.map_version must be a positive integer")
    nodes = graph.get("nodes", [])
    edges = graph.get("edges", [])
    if not isinstance(nodes, list):
        errors.append("graph.nodes must be an array")
        nodes = []
    if not isinstance(edges, list):
        errors.append("graph.edges must be an array")
        edges = []

    node_ids: list[str] = []
    node_by_id: dict[str, dict[str, Any]] = {}
    evidence_ids: list[str] = []
    evidence_by_id: dict[str, dict[str, Any]] = {}
    evidence_source_refs: list[tuple[str, str]] = []
    node_source_refs: list[tuple[str, str]] = []

    for index, node in enumerate(nodes):
        prefix = f"graph.nodes[{index}]"
        if not isinstance(node, dict):
            errors.append(f"{prefix} must be an object")
            continue
        node_id = node.get("id")
        if not isinstance(node_id, str) or not node_id:
            errors.append(f"{prefix}.id must be a non-empty string")
            continue
        node_ids.append(node_id)
        node_by_id[node_id] = node
        if not isinstance(node.get("title"), str) or not node.get("title"):
            errors.append(f"{prefix}.title must be a non-empty string")
        if node.get("kind") not in NODE_KINDS:
            errors.append(f"{prefix}.kind is invalid")
        node_sources = node.get("source_ids")
        if not isinstance(node_sources, list):
            errors.append(f"{prefix}.source_ids must be an array")
            node_sources = []
        elif not node_sources:
            errors.append(f"{prefix}.source_ids must contain at least one provenance source")
        for source_id in node_sources:
            if not isinstance(source_id, str) or not source_id:
                errors.append(f"{prefix}.source_ids must contain non-empty strings")
            else:
                node_source_refs.append((prefix, source_id))

        learning = node.get("learning")
        if not isinstance(learning, dict):
            errors.append(f"{prefix}.learning must be an object")
            continue
        current_level = learning.get("current_level")
        highest_level = learning.get("highest_level")
        if not isinstance(current_level, int) or isinstance(current_level, bool) or not 0 <= current_level <= 5:
            errors.append(f"{prefix}.learning.current_level must be 0..5")
            current_level = 0
        if not isinstance(highest_level, int) or isinstance(highest_level, bool) or not 0 <= highest_level <= 5:
            errors.append(f"{prefix}.learning.highest_level must be 0..5")
            highest_level = 0
        if highest_level < current_level:
            errors.append(f"{prefix}.learning.highest_level cannot be below current_level")
        confidence = learning.get("confidence")
        if not isinstance(confidence, (int, float)) or isinstance(confidence, bool) or not 0 <= confidence <= 1:
            errors.append(f"{prefix}.learning.confidence must be between 0 and 1")
        if learning.get("last_seen") is not None and not valid_timestamp(learning.get("last_seen")):
            errors.append(f"{prefix}.learning.last_seen must be null or a timestamp with timezone")
        if learning.get("next_review") is not None and not valid_timestamp(learning.get("next_review")):
            errors.append(f"{prefix}.learning.next_review must be null or a timestamp with timezone")
        error_patterns = learning.get("error_patterns")
        if not isinstance(error_patterns, list):
            errors.append(f"{prefix}.learning.error_patterns must be an array")

        evidence_list = learning.get("evidence", [])
        if not isinstance(evidence_list, list):
            errors.append(f"{prefix}.learning.evidence must be an array")
            evidence_list = []
        max_passed = 0
        max_independent = 0
        max_transfer = 0
        for ev_index, evidence in enumerate(evidence_list):
            ev_prefix = f"{prefix}.learning.evidence[{ev_index}]"
            if not isinstance(evidence, dict):
                errors.append(f"{ev_prefix} must be an object")
                continue
            for required_field in (
                "id",
                "at",
                "session_id",
                "kind",
                "result",
                "demonstrated_level",
                "independent",
                "hints_used",
                "artifact",
                "artifact_verified",
                "notes",
                "source_ids",
            ):
                if required_field not in evidence:
                    errors.append(f"{ev_prefix}.{required_field} is required")
            evidence_id = evidence.get("id")
            if not isinstance(evidence_id, str) or not evidence_id:
                errors.append(f"{ev_prefix}.id must be a non-empty string")
            else:
                evidence_ids.append(evidence_id)
                evidence_by_id[evidence_id] = evidence
            if not valid_timestamp(evidence.get("at")):
                errors.append(f"{ev_prefix}.at must be a timestamp with timezone")
            if not isinstance(evidence.get("session_id"), str) or not evidence.get("session_id"):
                errors.append(f"{ev_prefix}.session_id must be a non-empty string")
            evidence_kind = evidence.get("kind")
            if not isinstance(evidence_kind, str) or not evidence_kind:
                errors.append(f"{ev_prefix}.kind must be a non-empty string")
            if evidence.get("result") not in PASS_RESULTS:
                errors.append(f"{ev_prefix}.result must be pass, partial, or fail")
            demonstrated = evidence.get("demonstrated_level")
            if not isinstance(demonstrated, int) or isinstance(demonstrated, bool) or not 0 <= demonstrated <= 5:
                errors.append(f"{ev_prefix}.demonstrated_level must be 0..5")
                demonstrated = 0
            hints = evidence.get("hints_used")
            if not isinstance(hints, int) or isinstance(hints, bool) or not 0 <= hints <= 4:
                errors.append(f"{ev_prefix}.hints_used must be 0..4")
                hints = 4
            if not isinstance(evidence.get("independent"), bool):
                errors.append(f"{ev_prefix}.independent must be boolean")
            artifact = evidence.get("artifact")
            if artifact is not None and not safe_relative_path(artifact):
                errors.append(f"{ev_prefix}.artifact must be a safe project-relative path")
            if not isinstance(evidence.get("artifact_verified"), bool):
                errors.append(f"{ev_prefix}.artifact_verified must be boolean")
            if not isinstance(evidence.get("notes"), str) or not evidence.get("notes").strip():
                errors.append(f"{ev_prefix}.notes must be a non-empty string")
            evidence_sources = evidence.get("source_ids")
            if not isinstance(evidence_sources, list):
                errors.append(f"{ev_prefix}.source_ids must be an array")
                evidence_sources = []
            for source_id in evidence_sources:
                if not isinstance(source_id, str) or not source_id:
                    errors.append(f"{ev_prefix}.source_ids must contain non-empty strings")
                else:
                    evidence_source_refs.append((ev_prefix, source_id))
            if evidence.get("result") == "pass":
                max_passed = max(max_passed, demonstrated)
                if evidence.get("independent") is True and hints == 0:
                    max_independent = max(max_independent, demonstrated)
                    if evidence_kind in LEVEL_FIVE_EVIDENCE_KINDS:
                        max_transfer = max(max_transfer, demonstrated)
        if current_level > max_passed:
            errors.append(f"{prefix}.learning.current_level exceeds passing evidence")
        if highest_level > max_passed:
            errors.append(f"{prefix}.learning.highest_level exceeds passing evidence")
        if current_level >= 4 and max_independent < current_level:
            errors.append(f"{prefix}.learning level 4 or 5 requires independent passing evidence with zero hints")
        if max(current_level, highest_level) >= 5 and max_transfer < 5:
            errors.append(f"{prefix}.learning level 5 requires independent zero-hint transfer evidence")

    node_set = set(node_ids)
    if len(node_ids) != len(node_set):
        errors.append("graph node ids must be unique")
    if len(evidence_ids) != len(set(evidence_ids)):
        errors.append("evidence ids must be unique across the graph")
    evidence_set = set(evidence_ids)

    edge_source_refs: list[tuple[str, str]] = []
    valid_edges: list[dict[str, Any]] = []
    for index, edge in enumerate(edges):
        prefix = f"graph.edges[{index}]"
        if not isinstance(edge, dict):
            errors.append(f"{prefix} must be an object")
            continue
        valid_edges.append(edge)
        if edge.get("from") not in node_set or edge.get("to") not in node_set:
            errors.append(f"{prefix} references an unknown node")
        if edge.get("from") == edge.get("to"):
            errors.append(f"{prefix} cannot be a self-edge")
        if edge.get("type") not in EDGE_TYPES:
            errors.append(f"{prefix}.type is invalid")
        if not isinstance(edge.get("rationale"), str) or not edge.get("rationale").strip():
            errors.append(f"{prefix}.rationale must be a non-empty string")
        weight = edge.get("weight")
        if not isinstance(weight, (int, float)) or isinstance(weight, bool) or not 0 <= weight <= 1:
            errors.append(f"{prefix}.weight must be between 0 and 1")
        edge_sources = edge.get("source_ids")
        if not isinstance(edge_sources, list):
            errors.append(f"{prefix}.source_ids must be an array")
            edge_sources = []
        elif not edge_sources:
            errors.append(f"{prefix}.source_ids must contain at least one provenance source")
        for source_id in edge_sources:
            if not isinstance(source_id, str) or not source_id:
                errors.append(f"{prefix}.source_ids must contain non-empty strings")
            else:
                edge_source_refs.append((prefix, source_id))

    cycle = find_prerequisite_cycle(node_set, valid_edges)
    if cycle:
        errors.append("prerequisite edges contain a cycle: " + " -> ".join(cycle))

    for prefix, source_id in node_source_refs + evidence_source_refs + edge_source_refs:
        if source_id not in source_set:
            errors.append(f"{prefix} references unknown source: {source_id}")

    goal = data.get("goal")
    if not isinstance(goal, dict):
        errors.append("goal must be an object")
        goal = {}
    if not isinstance(goal.get("statement"), str) or not goal.get("statement"):
        errors.append("goal.statement must be a non-empty string")
    target_ids = goal.get("target_node_ids", [])
    if not isinstance(target_ids, list):
        errors.append("goal.target_node_ids must be an array")
        target_ids = []
    for node_id in target_ids:
        if not isinstance(node_id, str) or not node_id:
            errors.append("goal.target_node_ids must contain non-empty strings")
        elif node_id not in node_set:
            errors.append(f"goal references unknown target node: {node_id}")
    if len(target_ids) != len(set(node_id for node_id in target_ids if isinstance(node_id, str))):
        errors.append("goal target node ids must be unique")
    completion = goal.get("completion_contract")
    if not isinstance(completion, dict):
        errors.append("goal.completion_contract must be an object")
        completion = {}
    if not isinstance(completion.get("description"), str) or not completion.get("description").strip():
        errors.append("goal.completion_contract.description must be a non-empty string")

    goal_subgraph = data.get("goal_subgraph")
    if not isinstance(goal_subgraph, dict):
        errors.append("goal_subgraph must be an object")
        goal_subgraph = {}
    revision = goal_subgraph.get("revision")
    approved = goal_subgraph.get("user_approved_revision")
    if not isinstance(revision, int) or isinstance(revision, bool) or revision < 0:
        errors.append("goal_subgraph.revision must be a non-negative integer")
    if not isinstance(approved, int) or isinstance(approved, bool) or approved < 0:
        errors.append("goal_subgraph.user_approved_revision must be a non-negative integer")
    if isinstance(revision, int) and isinstance(approved, int) and revision != approved:
        errors.append("active goal_subgraph revision must be user-approved")
    subgraph_nodes = goal_subgraph.get("nodes", [])
    if not isinstance(subgraph_nodes, list):
        errors.append("goal_subgraph.nodes must be an array")
        subgraph_nodes = []
    subgraph_by_id: dict[str, dict[str, Any]] = {}
    for index, item in enumerate(subgraph_nodes):
        prefix = f"goal_subgraph.nodes[{index}]"
        if not isinstance(item, dict):
            errors.append(f"{prefix} must be an object")
            continue
        node_id = item.get("node_id")
        if node_id not in node_set:
            errors.append(f"{prefix} references an unknown node")
            continue
        if node_id in subgraph_by_id:
            errors.append("goal_subgraph node ids must be unique")
        subgraph_by_id[node_id] = item
        if not isinstance(item.get("required"), bool):
            errors.append(f"{prefix}.required must be boolean")
        target_level = item.get("target_level")
        if not isinstance(target_level, int) or isinstance(target_level, bool) or not 0 <= target_level <= 5:
            errors.append(f"{prefix}.target_level must be 0..5")
        goal_weight = item.get("goal_weight")
        if not isinstance(goal_weight, (int, float)) or isinstance(goal_weight, bool) or not 0 <= goal_weight <= 1:
            errors.append(f"{prefix}.goal_weight must be between 0 and 1")

    for node_id in target_ids:
        target_item = subgraph_by_id.get(node_id)
        if target_item is not None and target_item.get("required") is not True:
            errors.append(f"goal target node must be required in goal_subgraph: {node_id}")

    if target_ids:
        closure = prerequisite_closure(target_ids, valid_edges)
        missing = closure - set(subgraph_by_id)
        if missing:
            errors.append("goal_subgraph is missing prerequisite closure nodes: " + ", ".join(sorted(missing)))

    approved_fingerprint = goal_subgraph.get("approved_fingerprint")
    route_requires_approval = (
        project.get("status") in {"active", "complete"}
        or goal.get("status") in {"active", "complete"}
    )
    if approved_fingerprint is not None:
        if not isinstance(approved_fingerprint, str) or not re.fullmatch(
            r"sha256:[0-9a-f]{64}", approved_fingerprint
        ):
            errors.append("goal_subgraph.approved_fingerprint must be sha256:<64 lowercase hex>")
        elif approved_fingerprint != route_approval_fingerprint(data):
            errors.append("goal_subgraph.approved_fingerprint does not match the active route contract")
    elif route_requires_approval:
        errors.append("active or complete route requires goal_subgraph.approved_fingerprint")

    planner = data.get("planner")
    if not isinstance(planner, dict):
        errors.append("planner must be an object")
        planner = {}
    if planner.get("strategy") != "goal_weighted_spiral_bfs":
        errors.append("planner.strategy must be goal_weighted_spiral_bfs")
    planner_pass = planner.get("pass")
    if not isinstance(planner_pass, int) or isinstance(planner_pass, bool) or not 1 <= planner_pass <= 5:
        errors.append("planner.pass must be 1..5")
        planner_pass = 1
    pass_target = planner.get("pass_target_level")
    if not isinstance(pass_target, int) or isinstance(pass_target, bool) or not 1 <= pass_target <= 5:
        errors.append("planner.pass_target_level must be 1..5")
        pass_target = 1
    if planner_pass != pass_target:
        errors.append("planner.pass must equal planner.pass_target_level")
    if planner_pass > 1:
        for node_id, item in subgraph_by_id.items():
            if item.get("required") is not True:
                continue
            target_level = item.get("target_level")
            if not isinstance(target_level, int) or isinstance(target_level, bool):
                continue
            previous_gate = min(planner_pass - 1, target_level)
            current_level = node_by_id.get(node_id, {}).get("learning", {}).get("current_level", 0)
            if current_level < previous_gate:
                errors.append(
                    f"planner.pass skips prior gate for required node: {node_id}"
                )
    frontier = planner.get("frontier", [])
    if not isinstance(frontier, list):
        errors.append("planner.frontier must be an array")
        frontier = []
    if len(frontier) > 3:
        errors.append("planner.frontier may contain at most 3 nodes")
    frontier_ids: list[str] = []
    for index, item in enumerate(frontier):
        prefix = f"planner.frontier[{index}]"
        if not isinstance(item, dict):
            errors.append(f"{prefix} must be an object")
            continue
        node_id = item.get("node_id")
        frontier_ids.append(node_id)
        if node_id not in node_set:
            errors.append(f"{prefix} references an unknown node")
            continue
        score = item.get("score")
        if not isinstance(score, (int, float)) or isinstance(score, bool):
            errors.append(f"{prefix}.score must be numeric")
        if not isinstance(item.get("reasons"), list) or not item.get("reasons"):
            errors.append(f"{prefix}.reasons must be a non-empty array")
        for edge in valid_edges:
            if edge.get("type") == "prerequisite" and edge.get("to") == node_id:
                prerequisite_id = edge.get("from")
                prerequisite = node_by_id.get(prerequisite_id, {}).get("learning", {})
                target = subgraph_by_id.get(prerequisite_id, {}).get("target_level", pass_target)
                required_level = min(pass_target, target)
                if prerequisite.get("current_level", 0) < required_level:
                    errors.append(f"{prefix} includes node with unmet prerequisite: {prerequisite_id}")
    if len(frontier_ids) != len(set(frontier_ids)):
        errors.append("planner.frontier node ids must be unique")

    checkpoint = data.get("checkpoint")
    if not isinstance(checkpoint, dict):
        errors.append("checkpoint must be an object")
        checkpoint = {}
    for required_field in (
        "status",
        "session_id",
        "saved_at",
        "map_version",
        "active_node_id",
        "phase",
        "last_completed_action",
        "pending_question",
        "resume_summary",
        "verified",
        "blockers",
        "new_evidence_ids",
        "mastery_changes",
        "load_response",
        "pending_major_route_proposal",
        "next_action",
        "open_artifacts",
    ):
        if required_field not in checkpoint:
            errors.append(f"checkpoint.{required_field} is required for exact resume")
    if not valid_timestamp(checkpoint.get("saved_at")):
        errors.append("checkpoint.saved_at must be an ISO-8601 timestamp with timezone")
    if checkpoint.get("status") not in CHECKPOINT_STATUSES:
        errors.append("checkpoint.status is invalid")
    if checkpoint.get("phase") not in LOOP_PHASES:
        errors.append("checkpoint.phase is invalid")
    if checkpoint.get("map_version") != graph.get("map_version"):
        errors.append("checkpoint.map_version must match graph.map_version")
    for field in ("last_completed_action", "resume_summary", "next_action"):
        if not isinstance(checkpoint.get(field), str) or not checkpoint.get(field).strip():
            errors.append(f"checkpoint.{field} must be a non-empty string")
    session_id = checkpoint.get("session_id")
    if session_id is not None and (not isinstance(session_id, str) or not session_id.strip()):
        errors.append("checkpoint.session_id must be null or a non-empty string")
    if checkpoint.get("status") != "planning" and not isinstance(session_id, str):
        errors.append("non-planning checkpoint requires checkpoint.session_id")
    for field in ("verified", "blockers", "new_evidence_ids", "mastery_changes", "open_artifacts"):
        if not isinstance(checkpoint.get(field), list):
            errors.append(f"checkpoint.{field} must be an array")
    if checkpoint.get("status") == "awaiting_learner_response":
        pending_question = checkpoint.get("pending_question")
        if not isinstance(pending_question, str) or not pending_question.strip():
            errors.append("awaiting_learner_response requires a complete pending_question")
        elif not pending_question_is_durable(pending_question):
            errors.append(
                "pending_question must be self-contained or a durable .philomatheia/artifacts path, not an ephemeral locator"
            )
    active_node = checkpoint.get("active_node_id")
    if active_node is not None and active_node not in node_set:
        errors.append("checkpoint.active_node_id references an unknown node")
    if project.get("status") == "active":
        if goal.get("status") != "active":
            errors.append("active project requires goal.status active")
        if active_node is None:
            errors.append("active project requires checkpoint.active_node_id")
        elif active_node not in frontier_ids:
            errors.append("checkpoint.active_node_id must be in planner.frontier")
        if not frontier:
            errors.append("active project requires a non-empty frontier")
        if not target_ids:
            errors.append("active project requires goal target nodes")
        if not subgraph_nodes:
            errors.append("active project requires an approved goal subgraph")
    open_artifacts = checkpoint.get("open_artifacts")
    if not isinstance(open_artifacts, list):
        open_artifacts = []
    for artifact in open_artifacts:
        if not safe_relative_path(artifact):
            errors.append("checkpoint.open_artifacts must contain safe project-relative paths")
    new_evidence_ids = checkpoint.get("new_evidence_ids")
    if not isinstance(new_evidence_ids, list):
        new_evidence_ids = []
    for evidence_id in new_evidence_ids:
        if evidence_id not in evidence_set:
            errors.append(f"checkpoint references unknown evidence: {evidence_id}")

    inserted_review = planner.get("inserted_review_node_id")
    if inserted_review is not None:
        if inserted_review not in node_set:
            errors.append("planner.inserted_review_node_id references an unknown node")
        else:
            due = node_by_id[inserted_review].get("learning", {}).get("next_review")
            saved_at = checkpoint.get("saved_at")
            if not valid_timestamp(due) or not valid_timestamp(saved_at) or parse_timestamp(due) > parse_timestamp(saved_at):
                errors.append("inserted review node must be due at checkpoint time")

    if goal.get("status") == "complete":
        for node_id, item in subgraph_by_id.items():
            if item.get("required"):
                level = node_by_id[node_id].get("learning", {}).get("current_level", 0)
                if level < item.get("target_level", 0):
                    errors.append(f"complete goal has required node below target: {node_id}")
        if completion.get("status") != "passed":
            errors.append("complete goal requires a passed completion contract")
        completion_evidence_id = completion.get("evidence_id")
        if completion_evidence_id not in evidence_set:
            errors.append("complete goal requires valid integrative evidence")
        else:
            completion_evidence = evidence_by_id[completion_evidence_id]
            if completion_evidence.get("result") != "pass":
                errors.append("completion evidence must have result pass")
            if completion_evidence.get("independent") is not True:
                errors.append("completion evidence must be independent")
            if completion_evidence.get("hints_used") != 0:
                errors.append("completion evidence must use zero material hints")
            if completion_evidence.get("kind") not in INTEGRATIVE_EVIDENCE_KINDS:
                errors.append("completion evidence must have integration or capstone kind")
            if (
                completion_evidence.get("artifact") is not None
                and completion_evidence.get("artifact_verified") is not True
            ):
                errors.append("completion evidence artifact must be verified")

    if project.get("status") == "complete" and goal.get("status") != "complete":
        errors.append("complete project requires goal.status complete")

    if project.get("status") == "active" and len(frontier) == 1:
        warnings.append("active frontier has one node; record why two or three eligible nodes were not appropriate")
    return errors, warnings


def main() -> int:
    args = parse_args()
    try:
        data = json.loads(args.state.read_text(encoding="utf-8"))
    except FileNotFoundError:
        print(json.dumps({"ok": False, "errors": [f"state file not found: {args.state}"], "warnings": []}))
        return 2
    except json.JSONDecodeError as exc:
        print(json.dumps({"ok": False, "errors": [f"invalid JSON: {exc}"], "warnings": []}))
        return 2

    if not isinstance(data, dict):
        print(json.dumps({"ok": False, "errors": ["state root must be an object"], "warnings": []}))
        return 1

    errors, warnings = validate(data)
    print(json.dumps({"ok": not errors, "errors": errors, "warnings": warnings}, ensure_ascii=False))
    return 0 if not errors else 1


if __name__ == "__main__":
    sys.exit(main())
