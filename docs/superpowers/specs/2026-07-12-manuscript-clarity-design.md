# Manuscript Clarity Design

## Goal

NovelForge must write scenes that readers understand on the first pass. Mystery may
withhold one concrete fact, but it may not hide basic action, intention, causality or
meaning behind vague comparisons, unnamed feelings or repetitive body reactions.

## Design

The quality pipeline uses a hybrid gate. Deterministic analysis measures vague
references, hypothetical comparisons, filter reactions, circumlocution and exact
sentence collisions. Prompts receive the concrete findings, while only affected
paragraphs are rewritten. A scene is stored only after expansion, fitting and cleanup
have passed the same final checks.

Existing scenes are revalidated when production resumes. Scenes outside the size or
clarity contract, or scenes colliding with earlier manuscript prose, are regenerated
in sequence with the existing story context. This avoids waiting for the final repair
phase and preserves the saved project state.

## Acceptance Criteria

- Clear concrete prose passes; densely vague prose fails deterministically.
- Accepted scenes contain no exact significant sentence from earlier scenes.
- Paragraph cleanup removes only paragraphs carrying measured clarity/style defects.
- Scene fitting accepts a faithful target-sized condensation even when a very long
  source requires more than 50 percent reduction.
- Existing unclear, oversized or colliding scenes are regenerated on resume.
- No incomplete, unsafe, meta or prompt-derived text is stored.
- The installed app resumes the current book and produces new scenes without CPU hangs.

