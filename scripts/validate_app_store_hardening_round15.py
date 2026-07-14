#!/usr/bin/env python3
import json
import importlib.util
import re
from collections import Counter, defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SEED_PATH = ROOT / "ios/EnglishPlus/EnglishPlus/Resources/SeedData/question_bank_seed.json"


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8-sig")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def normalized(value: str) -> str:
    return " ".join(value.strip().casefold().split())


def semantic_key(prompt: str) -> str:
    without_prefix = re.sub(
        r"^(vocabulary|grammar|fill\s*blank|cloze|reading|translation|dialogue)\s+\d+-\d+:\s*",
        "",
        prompt,
        flags=re.IGNORECASE,
    )
    return normalized(without_prefix)


def main() -> int:
    payload = json.loads(SEED_PATH.read_text(encoding="utf-8"))
    items = payload["items"]
    generator_path = ROOT / "scripts/generate_ios_question_bank_seed.py"
    spec = importlib.util.spec_from_file_location("round15_question_generator", generator_path)
    require(spec is not None and spec.loader is not None, "Unable to load the deterministic question generator")
    generator_module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(generator_module)
    require(items == generator_module.build_items(), "Committed question seed does not match its deterministic generator")
    require(payload.get("questionBankSchemaVersion") == 6, "Round 15 question schema must be version 6")
    require(len(items) == 1080, "The published seed must retain all 1,080 stable question ids")
    require(len({item["id"] for item in items}) == len(items), "Question ids must be unique")
    require(all(item["reviewState"] == "approved" for item in items), "Runtime seed may contain approved items only")

    types = Counter(item["question"]["type"] for item in items)
    require(set(types) == {"vocabulary", "grammar", "fillBlank", "cloze", "reading", "translation", "dialogue"}, "All seven supported question types must remain covered")
    levels = Counter(item["level"] for item in items)
    require(set(levels) == {"A1", "A2", "B1", "B2"}, "Difficulty must span foundation through early high-school bridge")
    require(levels["B2"] >= 100, "Early high-school bridge coverage is too small")
    require(len({item["skill"] for item in items}) >= 30, "Question bank needs granular curriculum skills")
    require(len({item["unit"] for item in items}) >= 6, "Question bank needs curriculum-level units")

    answer_slots = Counter()
    families = defaultdict(list)
    for item in items:
        question = item["question"]
        options = question["options"]
        normalized_options = [normalized(option) for option in options]
        answer = normalized(question["answer"])
        require(len(options) == 4, f"{item['id']} must have exactly four choices")
        require(len(set(normalized_options)) == 4, f"{item['id']} contains duplicate choices")
        require(answer in normalized_options, f"{item['id']} answer is missing from choices")
        require(question["acceptedAnswers"], f"{item['id']} needs accepted answers")
        answer_slots[normalized_options.index(answer)] += 1
        families[semantic_key(question["prompt"])].append(item)

    require(answer_slots == Counter({0: 270, 1: 270, 2: 270, 3: 270}), "Source answer positions must be exactly balanced")
    require(len(families) >= 200, "The seed has too few distinct learning prompts")
    for key, family in families.items():
        taxonomy = {(item["level"], item["unit"], item["skill"]) for item in family}
        answers = {normalized(item["question"]["answer"]) for item in family}
        option_sets = {tuple(sorted(normalized(option) for option in item["question"]["options"])) for item in family}
        require(len(taxonomy) == 1, f"Semantic family has inconsistent difficulty or skill: {key[:80]}")
        require(len(answers) == 1, f"Semantic family has conflicting answers: {key[:80]}")
        require(len(option_sets) == 1, f"Semantic family has conflicting option sets: {key[:80]}")

    model = read("ios/EnglishPlus/EnglishPlus/Models/Question.swift")
    practice = read("ios/EnglishPlus/EnglishPlus/Features/Practice/PracticeCenterView.swift")
    repository = read("ios/EnglishPlus/EnglishPlus/Services/MockLearningRepository.swift")
    tests = read("ios/EnglishPlus/EnglishPlusTests/AuthenticationFlowAcceptanceTests.swift")
    generator = read("scripts/generate_ios_question_bank_seed.py")
    workflow = read(".github/workflows/ios-hardening-build.yml")

    for marker in [
        "var semanticKey: String",
        "excludingSemanticKeys:",
        "uniqueLearningItems(",
        "minimumAnswerCount",
        "rotationSeed:",
        "startingSlot",
        "recentConceptPenalty",
    ]:
        require(marker in model, f"Missing Round 15 grouping contract: {marker}")
    require("UUID().uuidString" in practice, "Free-practice sessions must rotate instead of replaying one deterministic set")
    require("ForEach(sets)" in practice and "ForEach(sets.prefix(18))" not in practice, "Every curriculum practice set must remain reachable")
    require(r"mission-\(studentUid)-\(dateKey)-r\(roundNumber)" in repository, "Daily missions need a stable per-student per-round seed")
    require(r"assignment-\(student.studentUid)-\(set.id)" in repository, "Teacher assignments need independent question rotation")

    for marker in [
        "QuestionBankQualityAcceptanceTests",
        "testCurriculumTaxonomyAndSourceOptionsMeetRound15Contract",
        "testBalancedSessionRejectsSemanticDuplicatesAndRepeatedAnswers",
        "testRuntimeOptionOrderUsesEveryCorrectAnswerSlotEvenly",
        "testRepairSetDoesNotRepeatAnyQuestionFromPrimarySession",
        "testRotationSeedChangesQuestionsWithoutChangingQualityContract",
        "testPracticeCatalogUsesGranularSkillsAndFiniteUniqueSets",
    ]:
        require(marker in tests, f"Missing Round 15 Swift acceptance coverage: {marker}")

    for marker in ["curriculum_metadata", "balanced_options", "translation_options", '"questionBankSchemaVersion": 6']:
        require(marker in generator, f"Question generator is missing deterministic quality rule: {marker}")
    require("validate_app_store_hardening_round15.py" in workflow, "macOS gate must run the Round 15 validator")
    require(".github/ci-triggers/round15-question-quality" in workflow, "Round 15 trigger must be watched by the isolated macOS gate")

    print(
        "Round 15 question quality contract passed: "
        f"{len(items)} ids, {len(families)} semantic prompts, "
        f"{len({item['skill'] for item in items})} skills, slots {dict(sorted(answer_slots.items()))}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
