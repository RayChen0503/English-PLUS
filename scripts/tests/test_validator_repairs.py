"""Offline regression tests. No production requests, account operations or secrets."""
import ast
import contextlib
import importlib.util
import io
import json
import plistlib
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parents[1]


def load(name):
    spec = importlib.util.spec_from_file_location(name, SCRIPTS / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


membership = load("validate_ios_xcode_project_sources")
models = load("validate_groq_cloudflare_proxy")
store0 = load("validate_store0_environment_isolation")
store4 = load("validate_store4_release_submission")
repair = load("validate_app_store_hardening_round10")
smoke = load("smoke_worker_firebase_runtime")

PROJECT = '''{
 rootObject = project;
 objects = {
  project = { mainGroup = group; targets = (app, tests,); };
  group = { isa = PBXGroup; children = (appgroup, testgroup,); sourceTree = "<group>"; };
  appgroup = { isa = PBXGroup; path = App; children = (source,); sourceTree = "<group>"; };
  testgroup = { isa = PBXGroup; path = Tests; children = (testsource,); sourceTree = "<group>"; };
  source = { isa = PBXFileReference; path = Same.swift; sourceTree = "<group>"; };
  testsource = { isa = PBXFileReference; path = Same.swift; sourceTree = "<group>"; };
  build /* Same.swift in Sources */ = { isa = PBXBuildFile; fileRef = source; };
  testbuild /* Same.swift in Sources */ = { isa = PBXBuildFile; fileRef = testsource; };
  app = { isa = PBXNativeTarget; name = App; buildPhases = (phase,); };
  tests = { isa = PBXNativeTarget; name = Tests; buildPhases = (testphase,); };
  phase = { isa = PBXSourcesBuildPhase; files = (build,); };
  testphase = { isa = PBXSourcesBuildPhase; files = (testbuild,); };
 };
}'''


class XcodeMembershipTests(unittest.TestCase):
    expected = {"App": {"App/Same.swift"}, "Tests": {"Tests/Same.swift"}}

    def test_correct_target_membership(self):
        self.assertEqual(membership.validate_membership(PROJECT, self.expected), [])

    def test_declaration_and_comment_cannot_replace_sources_phase_entry(self):
        text = PROJECT.replace("files = (build,)", "files = ()")
        self.assertIn("App/Same.swift", " ".join(membership.validate_membership(text, self.expected)))

    def test_test_target_membership_is_required(self):
        text = PROJECT.replace("files = (testbuild,)", "files = ()")
        self.assertIn("Tests/Same.swift", " ".join(membership.validate_membership(text, self.expected)))

    def test_same_filename_in_wrong_group_or_target_does_not_pass(self):
        text = PROJECT.replace("files = (build,)", "files = (testbuild,)")
        self.assertTrue(membership.validate_membership(text, self.expected))

    def test_missing_reference_and_malformed_project_fail(self):
        text = PROJECT.replace("fileRef = source", "fileRef = absent")
        self.assertIn("unresolved", " ".join(membership.validate_membership(text, self.expected)))
        with self.assertRaises((ValueError, IndexError)):
            membership.parse_project(PROJECT[:-1])


class ValidatorTests(unittest.TestCase):
    def test_models_are_checked_per_environment_not_by_comment(self):
        valid = '[vars]\nGROQ_DEFAULT_MODEL="openai/gpt-oss-20b"\n[env.production.vars]\nGROQ_DEFAULT_MODEL="openai/gpt-oss-20b"'
        errors = []
        models.validate_model_config(valid, errors)
        self.assertEqual(errors, [])
        errors = []
        models.validate_model_config(valid.replace('GROQ_DEFAULT_MODEL="openai/gpt-oss-20b"', 'GROQ_DEFAULT_MODEL="wrong"', 1), errors)
        self.assertEqual(len(errors), 1)
        self.assertIn("competition", errors[0])

    def test_missing_git_is_an_error_not_a_skipped_success(self):
        errors = []
        with patch.object(store0, "git", side_effect=OSError("unavailable")):
            self.assertFalse(store0.verify_git_refs(errors))
        self.assertIn("incomplete", errors[0])

    def test_mismatched_git_baseline_remains_an_error(self):
        errors = []
        with patch.object(store0, "git", return_value="wrong"):
            self.assertTrue(store0.verify_git_refs(errors))
        self.assertEqual(len(errors), 3)

    def test_plist_false_belongs_to_the_encryption_key(self):
        def xml(value): return plistlib.dumps(value).decode()
        self.assertTrue(store4.exempt_encryption_declared(xml({"ITSAppUsesNonExemptEncryption": False})))
        for value in ({"ITSAppUsesNonExemptEncryption": True, "unrelated": False},
                      {"ITSAppUsesNonExemptEncryption": "false"}, {"unrelated": False}, []):
            self.assertFalse(store4.exempt_encryption_declared(xml(value)))
        for malformed in ("not a plist", '<?xml version="1.0"?><plist><dict>'):
            self.assertFalse(store4.exempt_encryption_declared(malformed))

    def test_historical_marker_helpers_still_fail_under_python_optimization(self):
        for filename in ("validate_ios_learning_flow_round5.py", "validate_ios_learning_flow_round6.py", "validate_student_free_practice_round1.py"):
            tree = ast.parse((SCRIPTS / filename).read_text(encoding="utf-8"))
            helpers = ast.Module(body=[node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name in ("require", "require_markers", "require_absent")], type_ignores=[])
            namespace = {}
            exec(compile(helpers, filename, "exec", optimize=2), namespace)
            present = namespace.get("require_markers", namespace.get("require"))
            present("label", "needed", ["needed"])
            with self.assertRaises(AssertionError, msg=filename): present("label", "", ["needed"])
            with self.assertRaises(AssertionError, msg=filename): namespace["require_absent"]("label", "forbidden", ["forbidden"])

    def test_repair_capacity_counts_semantic_fallback_and_excludes_source(self):
        def item(identifier, prompt, level="A1", skill="grammar"):
            return {"id": identifier, "reviewState": "approved", "level": level, "skill": skill,
                    "question": {"type": "grammar", "prompt": prompt, "concept": "grammar"}}
        bank = [item("1", "Grammar 1-1: CAFE"), item("2", "Grammar 1-2: café"),
                item("3", "Another", "A2"), item("4", "Third", "A1", "different"),
                item("5", "Fourth", "A1", "different")]
        row = repair.repair_capacity(bank)[0]
        self.assertEqual(row, {"id": "1", "exact": 0, "with_fallback": 3})
        self.assertEqual(repair.repair_capacity(bank[:2])[0]["with_fallback"], 0)


class SmokeResourceTests(unittest.TestCase):
    def test_temporary_student_profile_declares_its_self_service_access_path(self):
        with patch.object(smoke, "request_json", return_value=smoke.Response(200, {}, {})) as request:
            smoke.create_temporary_student_profile({"localId": "temporary", "idToken": "fake"})
        self.assertEqual(request.call_args.kwargs["payload"]["fields"]["studentAccessPath"], {"stringValue": "age13OrOlder"})

    def test_missing_accounts_stop_before_network(self):
        with patch.object(sys, "argv", ["smoke", "--plist", "fake.plist"]), \
             patch.object(Path, "read_bytes", return_value=plistlib.dumps({"API_KEY": "fake"})), \
             patch.dict(smoke.os.environ, {}, clear=True), \
             patch.object(smoke, "request_json") as request:
            with self.assertRaises(SystemExit): smoke.main()
            request.assert_not_called()

    def test_all_configured_roles_reach_sign_in_without_undefined_global(self):
        env = {name: "fake" for pair in smoke.TEST_ACCOUNT_ENV.values() for name in pair}
        response = smoke.Response(401, {}, {})
        with patch.object(sys, "argv", ["smoke", "--plist", "fake.plist"]), \
             patch.object(Path, "read_bytes", return_value=plistlib.dumps({"API_KEY": "fake"})), \
             patch.dict(smoke.os.environ, env, clear=True), \
             patch.object(smoke, "request_json", return_value=response), \
             patch.object(smoke, "firebase_sign_in", side_effect=RuntimeError("stub")) as sign_in, \
             contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(smoke.main(), 1)
            self.assertEqual(sign_in.call_count, 3)

    def test_profile_exception_always_attempts_both_owned_cleanups(self):
        results = []
        temporary = {"idToken": "fake", "localId": "temporary", "email": "fake", "password": "fake"}
        with patch.object(smoke, "firebase_sign_up", return_value=temporary), \
             patch.object(smoke, "create_temporary_student_profile", side_effect=OSError("stub")), \
             patch.object(smoke, "request_json", side_effect=OSError("cleanup offline")) as profile_cleanup, \
             patch.object(smoke, "firebase_delete_temporary_account", return_value=smoke.Response(200, {}, {})) as auth_cleanup:
            smoke.exercise_account_deletion("fake", results)
            self.assertEqual(profile_cleanup.call_count, 2)
            auth_cleanup.assert_called_once_with("fake", "fake")
        self.assertEqual([row["status"] for row in results], ["failed", "failed", "failed", "passed"])
        self.assertIn("synthetic UID=temporary", results[1]["detail"])

    def test_cleanup_worker_retry_is_bounded_and_success_skips_fallbacks(self):
        results = []
        temporary = {"idToken": "secret-token", "localId": "synthetic-uid", "password": "secret-password"}
        with patch.object(smoke, "request_json", return_value=smoke.Response(200, {"result": {"completed": True}}, {})) as request, \
             patch.object(smoke, "firebase_delete_temporary_account") as auth_cleanup:
            smoke.cleanup_temporary_account("fake", temporary, results)
            request.assert_called_once_with(f"{smoke.WORKER_BASE_URL}/account", method="DELETE", token="secret-token", payload={"confirmation": "DELETE", "policyVersion": "2026-07-13"})
            auth_cleanup.assert_not_called()
        self.assertEqual(results[0]["status"], "passed")

    def test_pending_cleanup_keeps_incomplete_status_and_only_reports_synthetic_uid(self):
        results = []
        temporary = {"idToken": "secret-token", "localId": "synthetic-uid", "password": "secret-password"}
        with patch.object(smoke, "request_json", side_effect=[smoke.Response(202, {}, {}), smoke.Response(403, {}, {})]) as request, \
             patch.object(smoke, "firebase_delete_temporary_account", return_value=smoke.Response(200, {}, {})):
            smoke.cleanup_temporary_account("fake", temporary, results)
            self.assertEqual(request.call_count, 2)  # One Worker retry, then profile fallback.
        self.assertEqual(results[0]["status"], "failed")
        self.assertIn("synthetic-uid", results[0]["detail"])
        self.assertNotIn("secret-token", json.dumps(results))
        self.assertNotIn("secret-password", json.dumps(results))

    def test_completed_worker_deletion_does_not_attempt_redundant_emergency_cleanup(self):
        results = []
        temporary = {"idToken": "fake", "localId": "temporary", "email": "fake", "password": "fake"}
        responses = [smoke.Response(200, {"preview": {"classMembershipCount": 0}}, {}),
                     smoke.Response(200, {"result": {"completed": True, "retainedData": "anonymousAggregateOnly"}}, {}),
                     smoke.Response(400, {}, {}), smoke.Response(404, {}, {})]
        with patch.object(smoke, "firebase_sign_up", return_value=temporary), \
             patch.object(smoke, "create_temporary_student_profile", return_value=smoke.Response(200, {}, {})), \
             patch.object(smoke, "request_json", side_effect=responses), \
             patch.object(smoke, "cleanup_temporary_account") as cleanup:
            smoke.exercise_account_deletion("fake", results)
            cleanup.assert_not_called()
        self.assertTrue(all(row["status"] == "passed" for row in results))


if __name__ == "__main__":
    unittest.main()
