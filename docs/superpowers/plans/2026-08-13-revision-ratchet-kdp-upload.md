# Revision Ratchet and KDP Upload Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port the proven revision safeguards from KI Korrektur into NovelForge and make KDP upload verification non-destructive and truthful.

**Architecture:** Add a focused Swift revision-safety service and use it from the existing orchestrator revision gates. Extract pure validation and status logic from the Node sidecar so upload behavior can be tested without Amazon or a browser.

**Tech Stack:** Swift 5.9, SwiftData, Foundation, Node.js ESM, Puppeteer sidecar, Swift probe tests, Node built-in test runner.

---

### Task 1: Deterministic revision safety

**Files:**
- Create: `Sources/NovelForge/Services/RevisionSafety.swift`
- Create: `Scripts/RevisionSafetyProbe.swift`

- [ ] Write failing probe cases for lost numbers, negations, quote balance, tense,
  perspective and item-list loss.
- [ ] Run the probe and verify the missing API fails compilation.
- [ ] Implement `RevisionSafety.issues(source:candidate:)` with conservative checks.
- [ ] Run the probe and existing prose/prompt probes.

### Task 2: Blind order-swapped comparison

**Files:**
- Modify: `Sources/NovelForge/Services/Agents.swift`
- Modify: `Sources/NovelForge/Services/PipelineOrchestrator.swift`
- Modify: `Scripts/RevisionSafetyProbe.swift`

- [ ] Add failing parser/aggregation tests for A/B, B/A, ties and disagreement.
- [ ] Add a neutral A/B prompt that does not reveal the revised version.
- [ ] Call the judge in both orders and accept only two consistent candidate wins.
- [ ] Apply deterministic and blind gates to chapter revision, opening optimization
  and final AI style cleanup.
- [ ] Run targeted probes and `swift build`.

### Task 3: Offline upload preflight

**Files:**
- Create: `kdp-sidecar/upload-core.js`
- Create: `kdp-sidecar/test/upload.test.js`
- Modify: `kdp-sidecar/index.js`
- Modify: `kdp-sidecar/package.json`

- [ ] Add failing Node tests for job validation and offline dry-run status.
- [ ] Extract pure upload-job validation and result helpers.
- [ ] Return from `--dry-run` before launching Chrome.
- [ ] Verify `npm test` starts no browser and passes.

### Task 4: Truthful Swift upload result handling

**Files:**
- Modify: `Sources/NovelForge/Services/KDPUploadService.swift`
- Modify: `Scripts/RegressionProbe.swift`

- [ ] Add failing tests for complete, incomplete, stale and failed sidecar status.
- [ ] Add a typed result parser and validate draft URLs for real runs.
- [ ] Remove stale status before launch and clean temporary JSON after parsing.
- [ ] Make dry-run return preflight evidence without requiring a KDP login.
- [ ] Run regression probe and `swift build`.

### Task 5: End-to-end verification

**Files:**
- Modify only if a verified defect is found.

- [ ] Run all deterministic NovelForge probes.
- [ ] Run all Node sidecar tests.
- [ ] Run a local export and `ProofService` smoke test.
- [ ] Run KDP offline preflight on the generated fixture.
- [ ] Run the non-writing KDP login/session check if a local session exists.
- [ ] Build the app and inspect the final diff for unrelated changes.
