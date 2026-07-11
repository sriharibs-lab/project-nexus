"""
Tests for task 1G-006 — Source ingest auto-polling in CollectionViewModel.swift
and APIClient.swift (iOS).

These tests inspect Swift source files as text to verify the required
implementation patterns are present and correctly structured.
No Xcode or device required — no Swift compilation needed.

Covered test hints:
  1. Polling starts automatically after load() when items have queued/processing status
  2. Poll interval is exactly 4 seconds
  3. Polling stops when all items reach terminal status (completed/failed)
  4. Items are merged in-place (no full-list reload) — mergeItems() logic
  5. deinit cancels the poll task (navigate-away stops network calls)
  6. Pull-to-refresh cancels the existing poll before starting a new one (no doubling)
  7. Poll errors are silent — no alert surfaced to user
  8. No polling started when all items are already in terminal status
  9. SSE streamSSE fix: checks both "type" and "event" discriminant fields for done/error
"""

from __future__ import annotations

import os
import re
import unittest

# ---------------------------------------------------------------------------
# File paths — worktree first, fall back to main tree after merge
# ---------------------------------------------------------------------------

_WORKTREE = "/Users/srihari/Documents/Projects/Project Nexus/.claude/worktrees/wf_5a6a2270-719-14"
_MAIN = "/Users/srihari/Documents/Projects/Project Nexus"


def _wt(rel: str) -> str:
    """Return worktree path if present, else main-tree path."""
    wt = os.path.join(_WORKTREE, rel)
    mt = os.path.join(_MAIN, rel)
    return wt if os.path.exists(wt) else mt


COLLECTION_VM = _wt("app-ios/Nexus/Nexus/Features/Collection/CollectionViewModel.swift")
API_CLIENT    = _wt("app-ios/Nexus/Nexus/Core/Network/APIClient.swift")
ITEM_MODEL    = _wt("app-ios/Nexus/Nexus/Core/Models/Item.swift")


def _read(path: str) -> str:
    with open(path, encoding="utf-8") as f:
        return f.read()


# ---------------------------------------------------------------------------
# 1. File existence guard
# ---------------------------------------------------------------------------

class TestFilesExist(unittest.TestCase):
    """Both modified files must exist in the worktree."""

    def test_collection_vm_exists(self):
        self.assertTrue(os.path.exists(COLLECTION_VM), f"Missing: {COLLECTION_VM}")

    def test_api_client_exists(self):
        self.assertTrue(os.path.exists(API_CLIENT), f"Missing: {API_CLIENT}")

    def test_item_model_exists(self):
        self.assertTrue(os.path.exists(ITEM_MODEL), f"Missing: {ITEM_MODEL}")


# ---------------------------------------------------------------------------
# 2. Polling infrastructure in CollectionViewModel
# ---------------------------------------------------------------------------

class TestPollingInfrastructure(unittest.TestCase):
    """Core polling fields and types must be declared."""

    def setUp(self):
        self.vm = _read(COLLECTION_VM)

    def test_poll_interval_constant_declared(self):
        """pollInterval constant must be declared."""
        self.assertIn("pollInterval", self.vm)

    def test_poll_interval_is_4_seconds(self):
        """Poll interval must be exactly 4 seconds."""
        self.assertIn("pollInterval: TimeInterval = 4", self.vm)

    def test_poll_task_property_declared(self):
        """pollTask must be declared as an optional Task."""
        self.assertIn("pollTask:", self.vm)

    def test_poll_task_is_optional_task(self):
        """pollTask must be Task<Void, Never>? (nullable)."""
        self.assertIn("Task<Void, Never>?", self.vm)

    def test_active_statuses_set_declared(self):
        """activeStatuses must define which statuses require polling."""
        self.assertIn("activeStatuses", self.vm)

    def test_active_statuses_contains_pending(self):
        """activeStatuses must include .pending."""
        self.assertIn(".pending", self.vm)

    def test_active_statuses_contains_processing(self):
        """activeStatuses must include .processing."""
        self.assertIn(".processing", self.vm)

    def test_has_active_items_computed_property(self):
        """hasActiveItems computed property must be declared."""
        self.assertIn("hasActiveItems", self.vm)

    def test_has_active_items_uses_contains_check(self):
        """hasActiveItems uses items.contains { ... } pattern."""
        self.assertIn("items.contains {", self.vm)

    def test_main_actor_annotation(self):
        """CollectionViewModel must be @MainActor."""
        self.assertIn("@MainActor", self.vm)


# ---------------------------------------------------------------------------
# 3. startPollingIfNeeded() logic
# ---------------------------------------------------------------------------

class TestStartPollingIfNeeded(unittest.TestCase):
    """startPollingIfNeeded must only start a task when active items exist."""

    def setUp(self):
        self.vm = _read(COLLECTION_VM)

    def test_start_polling_if_needed_defined(self):
        """startPollingIfNeeded() method must exist."""
        self.assertIn("func startPollingIfNeeded()", self.vm)

    def test_start_polling_is_private(self):
        """startPollingIfNeeded() must be private."""
        self.assertIn("private func startPollingIfNeeded()", self.vm)

    def test_existing_poll_cancelled_before_new_one(self):
        """Any existing pollTask must be cancelled before starting a fresh poll."""
        vm = self.vm
        start = vm.find("func startPollingIfNeeded()")
        self.assertGreater(start, -1)
        block = vm[start : start + 600]
        cancel_pos  = block.find("pollTask?.cancel()")
        new_task_pos = block.find("pollTask = Task {")
        self.assertGreater(cancel_pos, -1, "pollTask?.cancel() must be called")
        self.assertGreater(new_task_pos, -1, "pollTask = Task { must be created")
        self.assertLess(cancel_pos, new_task_pos,
                        "cancel() must happen BEFORE the new Task is created")

    def test_guard_has_active_items_before_spawning_task(self):
        """Must guard hasActiveItems before spawning pollTask."""
        vm = self.vm
        start = vm.find("func startPollingIfNeeded()")
        block = vm[start : start + 600]
        self.assertIn("hasActiveItems", block)

    def test_start_polling_called_after_successful_load(self):
        """startPollingIfNeeded() must be called inside load() after items are fetched."""
        vm = self.vm
        load_start = vm.find("func load()")
        self.assertGreater(load_start, -1)
        load_block = vm[load_start : load_start + 500]
        self.assertIn("startPollingIfNeeded()", load_block)

    def test_task_uses_weak_self(self):
        """The polling Task must capture self weakly to avoid retain cycles."""
        self.assertIn("[weak self]", self.vm)

    def test_guard_weak_self_in_task(self):
        """Must guard let self inside the polling Task."""
        self.assertIn("guard let self else { return }", self.vm)


# ---------------------------------------------------------------------------
# 4. Poll loop termination
# ---------------------------------------------------------------------------

class TestPollLoopTermination(unittest.TestCase):
    """Poll loop must exit when all items reach terminal status."""

    def setUp(self):
        self.vm = _read(COLLECTION_VM)

    def test_while_loop_checks_task_cancelled(self):
        """Poll loop must check Task.isCancelled to respond to cancellation."""
        self.assertIn("Task.isCancelled", self.vm)

    def test_break_when_no_active_items(self):
        """Loop must break when hasActiveItems returns false."""
        vm = self.vm
        # The break after the !hasActiveItems check
        has_active_check_pos = vm.find("!self.hasActiveItems")
        self.assertGreater(has_active_check_pos, -1,
                           "!self.hasActiveItems check must exist in poll loop")
        # break must follow this check
        break_pos = vm.find("break", has_active_check_pos)
        self.assertGreater(break_pos, -1, "break must follow the hasActiveItems check")
        self.assertLess(break_pos - has_active_check_pos, 200,
                        "break should be within 200 chars of !hasActiveItems check")

    def test_sleep_cancellation_breaks_loop(self):
        """Task.sleep() cancellation (catch) must break the loop."""
        # The catch block for Task.sleep cancellation
        self.assertIn("break // Cancelled", self.vm)

    def test_poll_interval_used_for_sleep_nanoseconds(self):
        """Sleep uses pollInterval * 1_000_000_000 nanoseconds."""
        self.assertIn("pollInterval * 1_000_000_000", self.vm)


# ---------------------------------------------------------------------------
# 5. deinit cancels the poll task
# ---------------------------------------------------------------------------

class TestDeinitCancelsTask(unittest.TestCase):
    """deinit must cancel pollTask to stop network calls on navigate-away."""

    def setUp(self):
        self.vm = _read(COLLECTION_VM)

    def test_deinit_block_exists(self):
        """CollectionViewModel must have a deinit block."""
        self.assertIn("deinit {", self.vm)

    def test_deinit_cancels_poll_task(self):
        """deinit must cancel pollTask."""
        vm = self.vm
        deinit_start = vm.find("deinit {")
        self.assertGreater(deinit_start, -1)
        deinit_block = vm[deinit_start : deinit_start + 100]
        self.assertIn("pollTask?.cancel()", deinit_block)


# ---------------------------------------------------------------------------
# 6. pollOnce() — silent error handling
# ---------------------------------------------------------------------------

class TestPollOnce(unittest.TestCase):
    """pollOnce() fetches items; errors are silent (no user alert)."""

    def setUp(self):
        self.vm = _read(COLLECTION_VM)

    def test_poll_once_defined(self):
        """pollOnce() method must exist."""
        self.assertIn("func pollOnce()", self.vm)

    def test_poll_once_is_private_async(self):
        """pollOnce() must be private and async."""
        self.assertIn("private func pollOnce()", self.vm)

    def test_poll_once_calls_fetch_items(self):
        """pollOnce() must call APIClient.shared.fetchItems."""
        vm = self.vm
        poll_start = vm.find("func pollOnce()")
        block = vm[poll_start : poll_start + 300]
        self.assertIn("fetchItems(in:", block)

    def test_poll_once_calls_merge_items(self):
        """pollOnce() must call mergeItems() after fetching."""
        vm = self.vm
        poll_start = vm.find("func pollOnce()")
        block = vm[poll_start : poll_start + 300]
        self.assertIn("mergeItems(", block)

    def test_poll_once_has_silent_catch(self):
        """pollOnce() errors must be caught and NOT surfaced (no 'error = ...' inside)."""
        vm = self.vm
        poll_start = vm.find("func pollOnce()")
        next_func  = vm.find("\n    private func ", poll_start + 1)
        block = vm[poll_start:next_func] if next_func > -1 else vm[poll_start : poll_start + 400]
        self.assertIn("} catch {", block)
        # The catch block must NOT set self.error
        catch_pos = block.find("} catch {")
        catch_block = block[catch_pos : catch_pos + 200]
        self.assertNotIn("self.error =", catch_block)
        self.assertNotIn("error =", catch_block.replace("} catch {", ""))


# ---------------------------------------------------------------------------
# 7. mergeItems() — in-place update, no full reload
# ---------------------------------------------------------------------------

class TestMergeItems(unittest.TestCase):
    """mergeItems() must update items in-place by ID, preserving list order."""

    def setUp(self):
        self.vm = _read(COLLECTION_VM)

    def test_merge_items_defined(self):
        """mergeItems(_:) method must exist."""
        self.assertIn("func mergeItems(_ fetched: [Item])", self.vm)

    def test_merge_items_is_private(self):
        """mergeItems must be private."""
        self.assertIn("private func mergeItems(_ fetched: [Item])", self.vm)

    def test_merge_items_builds_id_dictionary(self):
        """mergeItems must build a dictionary keyed by item ID for O(1) lookup."""
        vm = self.vm
        merge_start = vm.find("func mergeItems(")
        block = vm[merge_start : merge_start + 600]
        # Dictionary(uniqueKeysWithValues:) or similar pattern
        self.assertIn("Dictionary(uniqueKeysWithValues:", block)

    def test_merge_items_updates_existing_by_index(self):
        """Existing items must be updated in place (updated[i] = fresh)."""
        vm = self.vm
        merge_start = vm.find("func mergeItems(")
        block = vm[merge_start : merge_start + 700]
        self.assertIn("updated[i] = fresh", block)

    def test_merge_items_appends_new_items(self):
        """Items in fetched but not in local list must be appended."""
        vm = self.vm
        merge_start = vm.find("func mergeItems(")
        block = vm[merge_start : merge_start + 700]
        self.assertIn("append(contentsOf:", block)

    def test_merge_items_assigns_back_to_items(self):
        """mergeItems must assign the merged array back to self.items."""
        vm = self.vm
        merge_start = vm.find("func mergeItems(")
        block = vm[merge_start : merge_start + 800]
        self.assertIn("items = updated", block)

    def test_merge_items_iterates_by_index(self):
        """Must iterate existing items by index to allow in-place mutation."""
        vm = self.vm
        merge_start = vm.find("func mergeItems(")
        block = vm[merge_start : merge_start + 600]
        self.assertIn(".indices", block)

    def test_merge_does_not_remove_local_items_absent_from_server(self):
        """Items absent from fetched are kept (mid-optimistic-delete protection).

        Verify by checking the comment or that there is no removeValue on the
        main 'updated' array (only fetchedById is mutated during iteration).
        """
        vm = self.vm
        merge_start = vm.find("func mergeItems(")
        block = vm[merge_start : merge_start + 800]
        # The merge should NOT call updated.remove(...) or updated.removeAll(...)
        self.assertNotIn("updated.remove(", block)
        self.assertNotIn("updated.removeAll(", block)


# ---------------------------------------------------------------------------
# 8. Item.IngestStatus — terminal vs active states
# ---------------------------------------------------------------------------

class TestIngestStatusModel(unittest.TestCase):
    """Item.IngestStatus must define pending, processing, completed, failed."""

    def setUp(self):
        self.item = _read(ITEM_MODEL)

    def test_ingest_status_enum_defined(self):
        """IngestStatus enum must be declared."""
        self.assertIn("enum IngestStatus", self.item)

    def test_pending_case_defined(self):
        """IngestStatus.pending case must exist (inline or separate declaration)."""
        item = self.item
        # Swift allows: case pending, processing, completed, failed (all inline)
        # or separate case declarations. Check that 'pending' appears after
        # 'enum IngestStatus'.
        enum_pos = item.find("enum IngestStatus")
        self.assertGreater(enum_pos, -1)
        block = item[enum_pos : enum_pos + 200]
        self.assertIn("pending", block)

    def test_processing_case_defined(self):
        """IngestStatus.processing case must exist."""
        item = self.item
        enum_pos = item.find("enum IngestStatus")
        block = item[enum_pos : enum_pos + 200]
        self.assertIn("processing", block)

    def test_completed_case_defined(self):
        """IngestStatus.completed case must exist."""
        item = self.item
        enum_pos = item.find("enum IngestStatus")
        block = item[enum_pos : enum_pos + 200]
        self.assertIn("completed", block)

    def test_failed_case_defined(self):
        """IngestStatus.failed case must exist."""
        item = self.item
        enum_pos = item.find("enum IngestStatus")
        block = item[enum_pos : enum_pos + 200]
        self.assertIn("failed", block)

    def test_is_ready_returns_true_for_completed(self):
        """isReady must be true only for .completed."""
        self.assertIn("isReady", self.item)
        item_src = self.item
        is_ready_pos = item_src.find("isReady")
        block = item_src[is_ready_pos : is_ready_pos + 60]
        self.assertIn("completed", block)

    def test_ingest_status_is_codable(self):
        """IngestStatus must conform to Codable for JSON decoding."""
        item_src = self.item
        ingest_enum_pos = item_src.find("enum IngestStatus")
        block = item_src[ingest_enum_pos : ingest_enum_pos + 80]
        self.assertIn("Codable", block)


# ---------------------------------------------------------------------------
# 9. Pull-to-refresh: only one poll task after refresh (no doubling)
# ---------------------------------------------------------------------------

class TestNoPollDoubling(unittest.TestCase):
    """Calling load() while polling active must produce exactly one poll task."""

    def setUp(self):
        self.vm = _read(COLLECTION_VM)

    def test_cancel_before_reassign_prevents_doubling(self):
        """startPollingIfNeeded() cancels existing task then creates one new task."""
        vm = self.vm
        start = vm.find("func startPollingIfNeeded()")
        block = vm[start : start + 800]
        # Count Task assignments in the method — should be exactly one
        task_assign_count = block.count("pollTask = Task {")
        self.assertEqual(task_assign_count, 1,
                         "Exactly one pollTask = Task { must exist in startPollingIfNeeded")

    def test_poll_task_nil_set_after_cancel(self):
        """pollTask is set to nil after cancel (clean reset)."""
        vm = self.vm
        start = vm.find("func startPollingIfNeeded()")
        block = vm[start : start + 300]
        cancel_pos = block.find("pollTask?.cancel()")
        nil_pos = block.find("pollTask = nil")
        self.assertGreater(nil_pos, -1, "pollTask = nil must appear in startPollingIfNeeded")
        self.assertGreater(nil_pos, cancel_pos, "nil assignment must come after cancel()")

    def test_load_calls_start_polling_once(self):
        """load() must call startPollingIfNeeded exactly once."""
        vm = self.vm
        load_start = vm.find("func load()")
        next_func  = vm.find("\n    func ", load_start + 1)
        load_block = vm[load_start:next_func] if next_func > -1 else vm[load_start : load_start + 400]
        count = load_block.count("startPollingIfNeeded()")
        self.assertEqual(count, 1, "startPollingIfNeeded() called exactly once in load()")


# ---------------------------------------------------------------------------
# 10. APIClient.fetchItems wired for polling
# ---------------------------------------------------------------------------

class TestAPIClientFetchItems(unittest.TestCase):
    """APIClient must expose fetchItems(in:) for the polling path."""

    def setUp(self):
        self.api = _read(API_CLIENT)

    def test_fetch_items_method_exists(self):
        """fetchItems(in:) must be declared in APIClient."""
        self.assertIn("func fetchItems(in collectionId: UUID)", self.api)

    def test_fetch_items_returns_item_array(self):
        """fetchItems must return [Item]."""
        self.assertIn("async throws -> [Item]", self.api)

    def test_fetch_items_calls_get_items_endpoint(self):
        """fetchItems must use the .items endpoint."""
        self.assertIn(".items(collectionId:", self.api)


# ---------------------------------------------------------------------------
# 11. SSE streamSSE type/event discriminant fix (Chat regression)
# ---------------------------------------------------------------------------

class TestSSEStreamDiscriminantFix(unittest.TestCase):
    """streamSSE must check both 'type' and 'event' fields for done/error termination."""

    def setUp(self):
        self.api = _read(API_CLIENT)

    def test_stream_sse_method_exists(self):
        """streamSSE method must exist on APIClient."""
        self.assertIn("func streamSSE<", self.api)

    def test_checks_type_field(self):
        """streamSSE must check the 'type' field in the SSE JSON."""
        self.assertIn('"type"', self.api)

    def test_checks_event_field(self):
        """streamSSE must check the 'event' field in the SSE JSON."""
        self.assertIn('"event"', self.api)

    def test_done_terminates_loop(self):
        """'done' value must terminate the SSE loop."""
        self.assertIn('"done"', self.api)

    def test_error_terminates_loop(self):
        """'error' value must terminate the SSE loop."""
        self.assertIn('"error"', self.api)

    def test_fallback_discriminant_pattern(self):
        """Must use fallback pattern: check 'type' OR 'event' key."""
        api = self.api
        # The ?? operator chaining both fields
        self.assertIn("eventDiscriminant", api)

    def test_both_type_and_event_checked_via_coalescence(self):
        """Both 'type' and 'event' must appear in the same discriminant expression."""
        api = self.api
        discriminant_pos = api.find("eventDiscriminant")
        self.assertGreater(discriminant_pos, -1)
        block = api[discriminant_pos : discriminant_pos + 200]
        self.assertIn('"type"', block)
        self.assertIn('"event"', block)

    def test_break_on_done_or_error(self):
        """Loop must break when discriminant is 'done' or 'error'."""
        api = self.api
        discriminant_pos = api.find("eventDiscriminant")
        block = api[discriminant_pos : discriminant_pos + 300]
        self.assertIn("break", block)
        self.assertIn('"done"', block)
        self.assertIn('"error"', block)

    def test_data_prefix_stripped_for_sse_parsing(self):
        """SSE parser must strip the 'data: ' prefix before JSON parsing."""
        self.assertIn('hasPrefix("data: ")', self.api)
        self.assertIn("dropFirst(6)", self.api)


# ---------------------------------------------------------------------------
# 12. First-poll delay and ordering
# ---------------------------------------------------------------------------

class TestFirstPollDelay(unittest.TestCase):
    """First poll fires after one full interval, not immediately after load."""

    def setUp(self):
        self.vm = _read(COLLECTION_VM)

    def test_initial_sleep_before_while_loop(self):
        """Task.sleep must be called before the while loop (delayed first poll)."""
        vm = self.vm
        task_body_start = vm.find("pollTask = Task {")
        self.assertGreater(task_body_start, -1)
        task_body = vm[task_body_start : task_body_start + 800]
        sleep_pos = task_body.find("Task.sleep(nanoseconds:")
        while_pos = task_body.find("while !Task.isCancelled")
        self.assertGreater(sleep_pos, -1, "Task.sleep must exist in pollTask body")
        self.assertGreater(while_pos, -1, "while loop must exist in pollTask body")
        self.assertLess(sleep_pos, while_pos,
                        "First sleep must come BEFORE the while loop (delayed first tick)")

    def test_poll_once_called_inside_while_loop(self):
        """pollOnce() must be called inside the while loop."""
        vm = self.vm
        while_pos = vm.find("while !Task.isCancelled")
        self.assertGreater(while_pos, -1)
        # Find the next closing brace that ends the while
        while_block = vm[while_pos : while_pos + 500]
        self.assertIn("pollOnce()", while_block)

    def test_poll_once_awaited(self):
        """pollOnce() must be awaited."""
        self.assertIn("await self.pollOnce()", self.vm)


if __name__ == "__main__":
    unittest.main()
