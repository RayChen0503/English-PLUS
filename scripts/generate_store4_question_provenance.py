#!/usr/bin/env python3
"""Generate a prompt-free provenance manifest for the shipping question bank."""

from __future__ import annotations

import hashlib
import json
import re
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SEED_PATH = ROOT / "ios/EnglishPlus/EnglishPlus/Resources/SeedData/question_bank_seed.json"
OUTPUT_PATH = ROOT / "docs/app-store-release/store-4/question-provenance-manifest.json"
ORIGINAL_SOURCE = "English+ original curriculum-aligned seed"


def load_bank() -> dict[str, object]:
    return json.loads(SEED_PATH.read_text(encoding="utf-8"))


def canonical_hash(value: object) -> str:
    payload = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def semantic_key(prompt: str) -> str:
    without_prefix = re.sub(
        r"^(vocabulary|grammar|fill\s*blank|cloze|reading|translation|dialogue)\s+\d+-\d+:\s*",
        "",
        prompt,
        flags=re.IGNORECASE,
    )
    return " ".join(without_prefix.strip().casefold().split())


def source_classification(source: str) -> tuple[str, str, str]:
    if source == ORIGINAL_SOURCE:
        return (
            "self_authored",
            "documented_internal_original",
            "Generated from the versioned English+ seed generator; official curriculum and CAP materials are difficulty and task-design references only.",
        )
    if source.startswith("public-domain:"):
        return "legally_public", "public_domain_recorded", source.removeprefix("public-domain:").strip()
    if source.startswith("licensed:"):
        return "licensed", "license_recorded", source.removeprefix("licensed:").strip()
    return "unresolved", "requires_human_review", source or "No source label"


def build_manifest() -> dict[str, object]:
    payload = load_bank()
    items = payload["items"]
    records = []
    classifications: Counter[str] = Counter()
    families: Counter[str] = Counter()

    for item in items:
        question = item["question"]
        family_hash = canonical_hash(semantic_key(question["prompt"]))
        classification, rights_status, evidence = source_classification(item.get("source", ""))
        classifications[classification] += 1
        families[family_hash] += 1
        records.append(
            {
                "id": item["id"],
                "questionType": question["type"],
                "level": item["level"],
                "sourceClassification": classification,
                "sourceLabel": item.get("source", ""),
                "rightsStatus": rights_status,
                "rightsEvidence": evidence,
                "reviewState": item.get("reviewState", ""),
                "importBatchId": item.get("importBatchId", ""),
                "questionContentSha256": canonical_hash(question),
                "semanticFamilySha256": family_hash,
            }
        )

    duplicate_family_sizes = Counter(size for size in families.values())
    return {
        "schemaVersion": 1,
        "app": "English+",
        "questionBankSchemaVersion": payload.get("questionBankSchemaVersion"),
        "questionCount": len(records),
        "manifestContainsQuestionText": False,
        "classificationCounts": dict(sorted(classifications.items())),
        "semanticFamilyCount": len(families),
        "semanticFamilySizeDistribution": {
            str(size): count for size, count in sorted(duplicate_family_sizes.items())
        },
        "sourcePolicy": {
            "officialExamMaterial": "difficulty_and_task_design_reference_only",
            "protectedVerbatimTextAllowed": False,
            "unresolvedItemsAllowedInRelease": False,
        },
        "records": records,
    }


def main() -> int:
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    manifest = build_manifest()
    OUTPUT_PATH.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(
        f"Generated STORE-4 provenance manifest: {manifest['questionCount']} items, "
        f"{manifest['semanticFamilyCount']} semantic families"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
