# Contributing to dc-sim

## The Golden Rule: Spec First

**No code without a spec.** Every feature, change, or component must have an approved spec in `specs/` before implementation begins. This is enforced by the `spec-check` CI workflow.

---

## Spec-Driven Development Workflow

```
1. Write spec     →  Create specs/XXX-feature-name.md
2. Open Issue     →  Use the "Spec" GitHub Issue template
3. Update spec    →  Add Issue number to spec front-matter
4. Review         →  Get at least one approval on the Issue
5. Implement      →  Open PRs referencing the spec (e.g. "Spec: SPEC-050")
6. Close          →  Mark spec Status as "Implemented"
```

---

## Writing a Spec

1. Copy the structure from an existing spec (e.g., [SPEC-050](specs/050-cmdb.md)).
2. Number it sequentially (next available `XXX` in `specs/`).
3. Required front-matter fields:
   - `**Status:**` — Draft / Approved / Implemented
   - `**GitHub Issue:**` — #N (fill in after opening the Issue)
   - `**Depends on:**` — list any SPEC-XXX this depends on

4. Required sections: Summary, (main content), Open Questions.
5. Open a GitHub Issue using the **Spec** template and link it in the spec file.

---

## Opening a Pull Request

- PR title: `[SPEC-XXX] Short description of change`
- PR body must contain either:
  - `Spec: SPEC-XXX` — references the relevant spec
  - `Closes #N` — closes the spec Issue (use when PR fully implements the spec)
- PRs that modify `services/` or `infra/` without a spec reference will fail CI.

---

## Branch Naming

| Type | Pattern | Example |
|------|---------|---------|
| Spec | `spec/XXX-short-name` | `spec/050-cmdb` |
| Feature | `feat/SPEC-XXX-short-desc` | `feat/SPEC-050-ci-table` |
| Bug fix | `fix/short-desc` | `fix/sim-engine-container-leak` |
| Chore | `chore/short-desc` | `chore/update-deps` |

---

## Commit Messages

```
<type>(scope): <short description>

[optional body]

Spec: SPEC-XXX
```

Types: `feat`, `fix`, `chore`, `docs`, `test`, `ci`, `refactor`

Example:
```
feat(cmdb): add CI relationship API endpoints

Implements /cmdb/cis/{id}/relationships per SPEC-050 section "API Endpoints".

Spec: SPEC-050
```

---

## Architecture Decisions

For significant design decisions (technology choices, architectural trade-offs), create an ADR in `docs/adr/`:
1. Copy the structure from an existing ADR.
2. Number sequentially.
3. Status: Proposed → Accepted / Rejected / Superseded.
4. Reference the ADR from the relevant spec's Open Questions section.

---

## Code Standards

Each service defines its own linting and testing targets via a `Makefile`. All services must provide:
- `make lint` — linting
- `make test` — unit tests
- `make build` — build/compile

These are called by the `ci.yml` workflow on each PR.
