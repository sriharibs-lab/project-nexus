"""
Shared pytest config.

Several NBL-era test modules install stubs into sys.modules (fake `app.core.config`,
fake `sqlalchemy`, ...) so a router can be exec'd without a database. Left in place,
those stubs leak into the next module and break its real imports — the collection
errors we saw were all cross-module pollution of this kind.

Two guards below snapshot sys.modules and repair it (a) after each test module is
imported during collection and (b) after each module's tests run, so every module
starts from a clean import state regardless of ordering.

Repair is conservative: entries whose object was swapped get the original back,
and *added* entries are dropped only when they are stubs (no `__spec__`) or belong
to this repo's packages. Real third-party modules are never evicted — re-importing
compiled extensions (sqlalchemy.cyextension, asyncpg) after eviction segfaults.
"""
import sys

import pytest

_PROJECT_PREFIXES = ("app", "ai", "pipeline", "tests")


def _is_project(name: str) -> bool:
    root = name.split(".", 1)[0]
    return root in _PROJECT_PREFIXES


def _is_stub(mod) -> bool:
    return mod is None or getattr(mod, "__spec__", None) is None


def _repair(snapshot: dict, keep: set[str] = frozenset()) -> None:
    for name, mod in list(sys.modules.items()):
        if name in keep:
            continue
        if name in snapshot:
            if snapshot[name] is not mod:
                sys.modules[name] = snapshot[name]
        elif _is_stub(mod) or _is_project(name):
            del sys.modules[name]
    for name, mod in snapshot.items():
        if name not in sys.modules:
            sys.modules[name] = mod


@pytest.hookimpl(wrapper=True)
def pytest_make_collect_report(collector):
    is_module = isinstance(collector, pytest.Module)
    snapshot = dict(sys.modules) if is_module else None
    try:
        return (yield)
    finally:
        if is_module:
            mod = getattr(collector, "module", None)
            keep = {mod.__name__} if mod is not None else set()
            _repair(snapshot, keep)


@pytest.fixture(autouse=True, scope="module")
def _isolate_sys_modules():
    snapshot = dict(sys.modules)
    yield
    _repair(snapshot)
