#!/usr/bin/env python3
"""Lint: a PaywallView must never show an INDEFINITE ProgressView on the
product-LOAD path (Apple Review 2.1(b) "loading forever" — lessons #5, #64).

Rule: any *PaywallView*.swift that renders a `ProgressView` must also consult
`loadingState` — the bounded product-load state machine
(IAPManager.LoadingState + productsLoadTimeout). A paywall that shows a spinner
without a `loadingState` switch can spin forever when StoreKit returns no
products (the common reviewer-sandbox case) → 2.1(b) reject.

This guard exists because the bug recurred in 3/8 apps (HabitHash, FocusFlow,
PromptVault) despite the canonical fix shipping in the other 5 — exactly the
"silent drift / partial fix" failure mode (lesson #54). It is wired into every
repo's ci.yml so a regression fails the build, and dogfooded via --selftest.

Usage:
    python3 scripts/lint_paywall_loadstate.py <source-root>   # e.g. AutoChoice
    python3 scripts/lint_paywall_loadstate.py --selftest
Exit 0 clean, 1 on violation.
"""
from __future__ import annotations
import sys
from pathlib import Path


def violations_in(src: str) -> list[str]:
    out: list[str] = []
    if "ProgressView" in src and "loadingState" not in src:
        out.append(
            "renders a ProgressView but never consults `loadingState` "
            "— an unbounded paywall spinner risks 2.1(b). Switch the "
            "product-unavailable branch on iap.loadingState (loading/loaded/"
            "empty/timedOut/failed) with a Try-again + continue-free path."
        )
    return out


def selftest() -> int:
    bad = """
    } else if let p = iap.products.first {
        Button("Buy") {}
    } else {
        ProgressView()
    }
    """
    good = """
    } else {
        switch iap.loadingState {
        case .loading: ProgressView()
        case .loaded, .empty, .timedOut, .failed: Button("Try again") {}
        }
    }
    """
    ok = True
    if not violations_in(bad):
        print("SELFTEST FAIL: known-bad snippet was NOT flagged")
        ok = False
    if violations_in(good):
        print("SELFTEST FAIL: known-good snippet WAS flagged (false positive)")
        ok = False
    print("SELFTEST", "PASS" if ok else "FAIL")
    return 0 if ok else 1


def main() -> int:
    if len(sys.argv) > 1 and sys.argv[1] == "--selftest":
        return selftest()
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
    found = 0
    violations = 0
    for swift in sorted(root.rglob("*.swift")):
        if "PaywallView" not in swift.name:
            continue
        found += 1
        src = swift.read_text(encoding="utf-8", errors="replace")
        for v in violations_in(src):
            print(f"{swift}: {v}")
            violations += 1
    if violations:
        print(f"\nFAIL: {violations} paywall load-state violation(s).")
        return 1
    print(f"OK: {found} PaywallView file(s), 0 load-state violations.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
