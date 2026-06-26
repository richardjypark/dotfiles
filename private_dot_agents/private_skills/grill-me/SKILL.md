---
name: grill-me
description: Use when the user wants to stress-test a plan or design before building, asks to be grilled, or types /grill-me; interview the user relentlessly one question at a time and recommend an answer for each question.
license: MIT
metadata:
  upstream:
    name: grilling
    url: https://github.com/mattpocock/skills/blob/main/skills/productivity/grilling/SKILL.md
---

# Grill Me

Interview the user relentlessly about every aspect of a plan or design until you reach a shared understanding.

Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

Ask questions one at a time, waiting for feedback on each question before continuing. Asking multiple questions at once is bewildering.

If a question can be answered by exploring the codebase, explore the codebase instead.

If the user invokes this skill without providing a plan or design, ask them to paste or summarize the plan first.
