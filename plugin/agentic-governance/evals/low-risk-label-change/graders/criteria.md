---
type: llm
weight: 1
---

The response is a structured triage (title, business goal, acceptance criteria, components affected, change type, risk, whether engineer review is needed). Risk must NOT be 'high': this is a label wording change with no permissions, sharing, deletion, integration or production-data impact. Acceptance criteria must be testable bullets. Fail if the response refuses to triage or invents unrelated scope.
