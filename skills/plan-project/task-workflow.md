# Skill Reference: Project Planning - Task Workflow

Conventions for epic/story creation, folder state machine, document standards, and templates used in project planning repos.

---

## Workflow

**Initiative → Epics → Stories → Tasks**

1. User sketches high-level goals in `main.md`
2. Agent parses `main.md` → creates epics in `epics/1_backlog/`
3. Agent breaks epics → creates stories in `stories/1_backlog/`
4. Agent moves files between state folders as work progresses

## Folder State Machine

```
epics/
  1_backlog/ → 2_planned/ → 3_in-progress/ → 5_completed/
  4_blocked/                               ↘ 6_cancelled/

stories/
  1_backlog/ → 2_ready/ → 3_in-progress/ → 4_in-review/ → 6_completed/
  5_blocked/                                              ↘ 7_cancelled/
```

**State = folder location. No state field inside files. Numeric prefixes maintain sort order.**

---

## Documentation Output

All docs go in `docs/`:

| Subfolder | Content |
|-----------|---------|
| `1_initiative/` | Initiative-level docs (overview, executive summary) |
| `2_epics/` | Epic-specific documentation |
| `3_playbooks/` | Playbooks and procedures |
| `4_architecture/` | Architecture decisions and diagrams |
| `5_reports/` | Reports, inventories, tracking |

**Never create docs in the repo root.**

---

## Document Length

| Type | Max Lines | Focus |
|------|-----------|-------|
| Epics | 100 | What/why/deliverables. Link to initiative docs, don't duplicate. |
| Stories | 75 | Specific work unit with clear acceptance criteria. |
| Initiative docs | Unrestricted | Comprehensive narrative. Deep context lives here. |

---

## Writing Style

- **Narrative over checklist** — explain "why this matters," not just "what to do"
- **Document relationships:** initiative docs → epics → stories (each references parent, never repeats)
- **Executive briefs** (`summary.md`): 50–100 lines, no abbreviations, KPIs/blockers/next steps/business value
- **C/V-level docs:** spell out all terms
- **Technical docs:** abbreviations OK after first definition

---

## Story Points (Fibonacci)

| Points | Effort | Time |
|--------|--------|------|
| 1 | Minimal, straightforward | < 1 day |
| 2 | Small, minor adjustments | 1–2 days |
| 3 | Medium, significant refactoring | 3–5 days |
| 5 | Large, extensive refactoring | 5–8 days |
| 8 | Extra large | 8+ days |
| 13 | **Too large — break it down** | Indeterminate |

**Epics do NOT have effort estimates.**

---

## Epic Template

```markdown
# XX: [Name]

**Priority:** P0 | P1 | P2 | P3
**Dependencies:** [Epic IDs or None]
**Skillsets:** [Required]

---

## Description

[1-2 paragraph narrative explaining scope and purpose]

**Why this matters:** [Business value and context]

**Scope:**
- [Bullet 1]
- [Bullet 2]

**Key Activities:**
1. **[Category 1]** (Stories X-Y): [Description]
2. **[Category 2]** (Stories X-Y): [Description]

**Outputs:**
- [Deliverable 1]
- [Deliverable 2]

**Timeline:** [Estimate] | **Team:** [Size/roles] | **[Detailed context →](link)**

---

## Acceptance Criteria

**[Category 1]:**
- [ ] [Measurable criterion]

**[Category 2]:**
- [ ] [Measurable criterion]

---

## Critical Dependencies

[Dependency diagram or bulleted list]

---

**Stories:** [Count] | **[View story breakdown →](link)**
```

---

## Story Template

```markdown
# XX.Y: [Name]

**Epic:** XX
**Effort:** 1 | 2 | 3 | 5 | 8 | 13
**Dependencies:** [Story IDs or None]
**Skillsets:** [Required]

---

## Description

[1-2 paragraph description of what needs to be done and why]

**Scope:**
- [What to accomplish]
- [Key deliverables]
- [Success indicators]

**Context:**
[Why this story matters, how it fits the epic, important background]

**Outputs:**
- [Deliverable 1]
- [Deliverable 2]

---

## Acceptance Criteria

- [ ] [Measurable criterion 1]
- [ ] [Measurable criterion 2]
- [ ] [Measurable criterion 3]

**Validation:**
- [ ] [Verification step 1]
- [ ] [Verification step 2]
```
