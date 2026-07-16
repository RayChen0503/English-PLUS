# STORE-4 Question Provenance and Content Rights Audit

Status: locally verified; final owner attestation pending before App Store submission.

## Release inventory

- Shipping file: `question_bank_seed.json`
- Total records: 1,080
- Supported types: vocabulary 120, grammar 180, fill blank 180, cloze 160, reading 140, translation 180, dialogue 120
- Source label: `English+ original curriculum-aligned seed` on all 1,080 records
- Review state: `approved` on all 1,080 records
- Versioned generator: `scripts/generate_ios_question_bank_seed.py`
- Import batch: `app-store-hardening-round-15-question-taxonomy`
- Distinct semantic families: 218

## Rights classification

All shipping records are classified as **self-authored** based on the committed,
deterministic English+ generator and the source label embedded in every item.
National curriculum and CAP materials are used only to define learning scope,
difficulty and task style. No official question, answer, passage or explanation
is designated as copied source text.

The release manifest stores only stable ids, classifications and SHA-256 hashes.
It intentionally excludes prompts, choices, answers and explanations so that a
public provenance artifact cannot become a second distribution copy of question
content.

## Duplicate and template finding

The 1,080 stable ids belong to 218 semantic families. Repeated members are
deterministic variants used for rotation and answer-position balancing, not 1,080
independent authored concepts. Runtime selection rejects duplicate semantic
families inside a session. This is acceptable for the current release only if the
store description says "1,080 題分級練習" rather than implying 1,080 unique
learning concepts.

## Release rules

1. `unresolved` provenance is a release blocker.
2. Any imported public or licensed material must identify its source and rights
   basis before it can become `approved`.
3. Merely being visible on the internet does not make a question reusable.
4. A future item derived from an official exam must use a newly written scenario,
   prompt, choices and explanation; only the assessed skill and difficulty may be
   retained.
5. The product owner must disclose any manually copied external material that is
   not represented in Git history before submission.
6. Run `python scripts/generate_store4_question_provenance.py` and
   `python scripts/validate_store4_release_submission.py` after every bank change.

## Human attestation required

Before submission, the product owner must confirm in writing:

> To the best of my knowledge, the shipping English+ question bank contains
> original English+ wording or content with recorded permission. I have disclosed
> any external source that was manually copied into the project.

This is a release record, not a legal opinion. If any external workbook, past exam,
commercial question bank or website was copied verbatim, those records must be
removed, rewritten or supported by a valid licence before release.
