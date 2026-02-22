# ADR-002: CMDB Storage Backend

**Status:** Proposed
**Date:** 2026-02-22
**Deciders:** dc-sim team

---

## Context

The CMDB needs to store heterogeneous CI attributes (flexible schema) and support relationship queries (impact analysis: "what does this VM affect?"). We need to decide between a relational store with JSONB and a native graph database.

## Options Considered

### Option A: PostgreSQL + JSONB
- CI attributes stored as JSONB in a `cis` table.
- Relationships stored in a `relationships` table (adjacency list).
- Graph traversal via recursive CTEs.
- Already used by itsm and patch-manager — one less dependency.

### Option B: Neo4j
- Native graph model maps naturally to CI relationships.
- Cypher queries are expressive for impact analysis.
- Additional infrastructure dependency.
- Smaller ecosystem for Go/Python ORMs.

## Decision

**Use PostgreSQL + JSONB** (Option A) for v1.

The relationship queries needed for impact analysis (typically 2-3 hops) are well within PostgreSQL's recursive CTE capability. Adding Neo4j would increase infrastructure complexity without a clear v1 benefit. If graph traversal becomes a bottleneck in v2, migrate CMDB to Neo4j with the same API surface.

## Consequences

- CMDB uses PostgreSQL (shared instance with itsm, patch-manager, or separate DB per service).
- Impact analysis queries use recursive CTEs — must be profiled for performance.
- Migration path to Neo4j is feasible: CMDB API surface stays the same, only the storage layer changes.
