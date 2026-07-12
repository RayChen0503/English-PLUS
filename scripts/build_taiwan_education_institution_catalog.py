#!/usr/bin/env python3
"""Normalize official Taiwan education directories into an iOS-ready catalog.

The script is intentionally offline and deterministic. Downloaded source files
are supplied explicitly so a release never changes because a remote endpoint
changed during a build.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


KIND_MAP = {
    "elementary": "elementarySchool",
    "juniorHigh": "juniorHighSchool",
    "seniorHigh": "seniorHighSchool",
    "combined": "combinedSchool",
    "experimental": "experimentalEducationInstitution",
}

HEADER_ALIASES = {
    "code": ("代碼", "學校代碼", "學校統計處代碼", "school_code"),
    "name": ("學校名稱", "校名", "機構名稱", "school_name"),
    "city": ("縣市名稱", "縣市別", "縣市", "主管機關(縣市)", "city"),
    "district": ("行政區", "鄉鎮市區", "district"),
}


@dataclass(frozen=True)
class SourceSpec:
    kind: str
    path: Path
    dataset_id: str
    academic_year: str


def read_rows(path: Path) -> list[dict[str, str]]:
    last_error: UnicodeDecodeError | None = None
    for encoding in ("utf-8-sig", "utf-8", "cp950"):
        try:
            with path.open("r", encoding=encoding, newline="") as handle:
                if path.suffix.lower() == ".json":
                    payload = json.load(handle)
                    if isinstance(payload, dict):
                        payload = payload.get("data") or payload.get("records") or []
                    return [dict(row) for row in payload if isinstance(row, dict)]
                return [dict(row) for row in csv.DictReader(handle)]
        except UnicodeDecodeError as error:
            last_error = error
    if last_error:
        raise last_error
    return []


def value(row: dict[str, str], field: str) -> str:
    for alias in HEADER_ALIASES[field]:
        candidate = str(row.get(alias) or "").strip()
        if candidate:
            return candidate
    return ""


def stable_id(code: str, name: str, city: str, kind: str) -> str:
    if code:
        return f"moe-{code.lower()}"
    digest = hashlib.sha256(f"{name}|{city}|{kind}".encode("utf-8")).hexdigest()[:16]
    return f"moe-generated-{digest}"


def normalize_source(source: SourceSpec) -> Iterable[dict[str, object]]:
    output_kind = KIND_MAP[source.kind]
    for row in read_rows(source.path):
        name = value(row, "name")
        if not name:
            continue
        code = value(row, "code")
        city = re.sub(r"^\[[^\]]+\]", "", value(row, "city")).strip()
        district = value(row, "district")
        academic_year = str(row.get("學年度") or source.academic_year).strip()
        yield {
            "id": stable_id(code, name, city, output_kind),
            "officialCode": code or None,
            "name": name,
            "city": city or None,
            "district": district or None,
            "kind": output_kind,
            "source": "ministryOfEducation",
            "sourceDatasetId": source.dataset_id,
            "sourceAcademicYear": academic_year,
            "isActive": True,
        }


def build_catalog(sources: Iterable[SourceSpec]) -> list[dict[str, object]]:
    records: dict[str, dict[str, object]] = {}
    for source in sources:
        for record in normalize_source(source):
            records[str(record["id"])] = record
    return sorted(
        records.values(),
        key=lambda item: (
            str(item.get("city") or ""),
            str(item["kind"]),
            str(item["name"]),
        ),
    )


def parse_source(raw: str, academic_year: str) -> SourceSpec:
    try:
        kind, dataset_id, path = raw.split("=", maxsplit=2)
    except ValueError as error:
        raise argparse.ArgumentTypeError(
            "source must use KIND=DATASET_ID=PATH"
        ) from error
    if kind not in KIND_MAP:
        raise argparse.ArgumentTypeError(f"unsupported kind: {kind}")
    source_path = Path(path)
    if not source_path.is_file():
        raise argparse.ArgumentTypeError(f"source file not found: {source_path}")
    return SourceSpec(kind, source_path, dataset_id, academic_year)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--academic-year", required=True)
    parser.add_argument(
        "--source",
        action="append",
        required=True,
        help="KIND=DATASET_ID=PATH (repeat for each official source)",
    )
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    sources = [parse_source(raw, args.academic_year) for raw in args.source]
    payload = {
        "schemaVersion": 1,
        "academicYear": args.academic_year,
        "institutions": build_catalog(sources),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
