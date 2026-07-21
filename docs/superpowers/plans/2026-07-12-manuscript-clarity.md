# Manuscript Clarity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent vague, repetitive and badly sized scenes before they enter a NovelForge manuscript.

**Architecture:** Extend the deterministic content-quality service with a clarity contract and fitting ratios. Apply those checks during candidate selection, paragraph cleanup, existing-scene validation and final acceptance. Keep provider work targeted to defective paragraphs wherever possible.

**Tech Stack:** Swift 5.9, SwiftData, SwiftUI, Foundation, Swift Package Manager

---

### Task 1: Deterministic clarity contract

**Files:**
- Modify: `Sources/NovelForge/Services/AutonomousContentQuality.swift`
- Test: `Tests/NovelForgeTests/LogicTests.swift`
- Test: `Scratch/RepetitionProbe/main.swift`

- [ ] Add failing tests proving dense vague comparisons fail while concrete action passes.
- [ ] Add phrase-match and density functions for vague references, hypothetical comparisons and filter reactions.
- [ ] Fold clarity defects into draft quality ranking.
- [ ] Run the standalone production-code probe.

### Task 2: Early drafting and paragraph repair

**Files:**
- Modify: `Sources/NovelForge/Services/Agents.swift`
- Modify: `Sources/NovelForge/Services/PipelineOrchestrator.swift`
- Test: `Tests/NovelForgeTests/LogicTests.swift`

- [ ] Add the clarity contract and concrete retry findings to scene prompts.
- [ ] Require clarity when ranking and accepting generated candidates.
- [ ] Extend paragraph cleanup to rewrite measured clarity defects and reject replacement defects.
- [ ] Recheck after expansion, fitting and prose normalization.

### Task 3: Existing-scene and repetition recovery

**Files:**
- Modify: `Sources/NovelForge/Services/PipelineOrchestrator.swift`
- Test: `Tests/NovelForgeTests/LogicTests.swift`

- [ ] Revalidate existing scenes for clarity and size when a paused book resumes.
- [ ] Compare every existing scene against prior manuscript prose before skipping it.
- [ ] Replace full-scene collision cleanup with paragraph-level replacement.
- [ ] Mark superseded scene warnings fixed after a clean replacement is stored.

### Task 4: Reliable scene sizing

**Files:**
- Modify: `Sources/NovelForge/Services/AutonomousContentQuality.swift`
- Modify: `Sources/NovelForge/Services/PipelineOrchestrator.swift`
- Test: `Tests/NovelForgeTests/LogicTests.swift`

- [ ] Add a target-aware minimum source ratio for large condensations.
- [ ] Retry fitting up to three times with explicit completeness instructions.
- [ ] Accept target-sized complete condensations below the former fixed 50 percent ratio.
- [ ] Correct warning text for both undersized and oversized scenes.

### Task 5: Build, install and live verification

**Files:**
- Modify: `Scripts/build-app.sh`

- [ ] Run debug build and standalone adversarial probes.
- [ ] Run release build, bump local app version and verify code signature.
- [ ] Back up and integrity-check the SwiftData store.
- [ ] Install into `/Applications/NovelForge.app` and resume the paused book.
- [ ] Verify new scenes for clarity, repetition, truncation, prompt artifacts, heartbeat and sleep assertion.

