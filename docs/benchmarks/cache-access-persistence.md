# Benchmark: persisting cache access time — file `mtime` vs SQLite

A spike to decide how the disk cache should persist per-entry *last access* (for the sliding TTL /
warm-cold expiry) across launches, **without a separate manifest** that can drift from the files.

Two co-located approaches were compared:

- **Option 1 — file `mtime`.** Re-`setAttributes` the file's modification date on a hit; the sweep
  `stat`s the cache directory. The timestamp lives *on* the file — nothing separate to sync. Also measured
  **sharded**: split the directory into K subdirectories and sweep one per launch (O(N/K) per launch).
- **Option 2 — SQLite index.** A row per entry (`key TEXT PRIMARY KEY, ts REAL`, indexed on `ts`);
  `UPSERT` on a hit, an indexed `SELECT` for the sweep.

Reproduce: `swift Benchmarks/CacheAccessPersistence.swift [entryCount accessCount]` (defaults 10k / 100k).
SQLite uses WAL + `synchronous=NORMAL` (the realistic durable-but-fast config). Numbers below are from
one run on macOS/APFS (Apple silicon) — indicative; absolute values differ on device, but the relative
picture is what matters.

## Results (10,000 entries, 100,000 accesses)

| Operation | Option 1 — `mtime` | Option 2 — SQLite |
|---|--:|--:|
| **recordAccess** (hot path, per read) | 25 µs touch · **15 µs** debounced (stat only) | **34 µs** autocommit · 2 µs batched (1 txn) |
| **sweep** (once per launch, 10k entries) | **~39 ms** | **~1 ms** |
| **footprint** | **0 bytes** extra | ~650 KB db + `-wal`/`-shm` sidecar |
| **moving parts** | none (timestamp on the file) | schema, C-API plumbing, a second store that can drift |

### Sweep scaling — where `mtime` spikes, and how sharding fixes it

The sweep is the O(n) operation (it must `stat` every file), so it's the one that blows up as the cache
grows. **Sharding** the cache directory into K subdirectories and sweeping just one shard per launch makes
each launch O(N/K); SQLite instead answers with an indexed range query:

| entries | full `mtime` | **sharded 1/16** | SQLite |
|--:|--:|--:|--:|
| 10,000 | 40 ms | 3 ms | 1 ms |
| 50,000 | 198 ms | 13 ms | 5 ms |
| 100,000 | 412 ms | 24 ms | 12 ms |
| 200,000 | **864 ms** | **53 ms** | 33 ms |

The full `mtime` scan spikes to ~0.9 s at 200k. Sharded (scan 1 of 16 per launch) cuts that ~16× to
**53 ms — the same ballpark as SQLite's 33 ms**, with zero dependency. The hot path barely moves with N
(per-op), so the sweep is the only place scale hurts, and sharding resolves it.

## Reading it

- **Hot path (the one that matters — runs on every cache read):** `mtime` touch (26 µs) and SQLite
  autocommit (31 µs) are **comparable** — both are bound by per-op durability, not the data structure.
  Debouncing the `mtime` touch (only re-touch when it's already stale) drops the common read to a bare
  `stat` (~15 µs here, and that's inflated by `URL.resourceValues`; a raw `stat` is cheaper). SQLite only
  wins the hot path if you **batch** writes in a transaction (1.5 µs) — but batching means buffering
  access updates and flushing later, which adds a crash-loss window and a flush policy. For the cache's
  bookkeeping that complexity isn't worth it.
- **Sweep:** the `mtime` scan grows with total entries — fine at 10k (~40 ms) but a **0.4–0.9 s spike at
  100k–200k**, since it must `stat` every file. Two ways to tame it: **shard** (scan 1 of K shard
  directories per launch → O(N/K)), or **SQLite** (indexed `SELECT`). Sharding at K=16 keeps the
  per-launch sweep at **~53 ms even at 200k** — within ~1.5× of SQLite — while staying zero-dependency.
  Its cost is *bounded GC latency*: a never-requested dead file lingers up to K launches before its
  shard's turn (anything you actually request is expired immediately by the lazy-on-read check, so this
  only delays garbage collection, never serves stale data), plus a one-integer "next shard" counter (not a
  per-entry index — nothing to drift) and a shard prefix in the key→path mapping.
- **Footprint & complexity:** `mtime` adds zero storage and zero moving parts; the timestamp can't drift
  from the file. SQLite adds a ~650 KB DB (+ WAL sidecars), the C-API plumbing, and — crucially — a
  *second store to keep in sync with the files*, which is exactly the manifest problem we set out to avoid.

## Recommendation

**Option 1 — `mtime`, debounced, sharded from the start.** `mtime` ties SQLite on the hot path, is
zero-dependency, zero-footprint, and self-syncing (no second store to drift). Shard the cache directory
**unconditionally** (derive the shard from the low bits of the key hash that `destinationURL` already
computes for the 255-char fix) and sweep one shard per launch — the per-launch sweep stays in the tens of
ms at any size, so the spike never happens.

Shard from the start, not on-the-fly: an always-sharded layout is *one* code path with no migration, no
entry-count tracking, and no threshold to tune, whereas switching layouts at runtime needs an O(N) reorg
and two code paths. The small-cache cost is negligible (a few mostly-empty subdirectories; dead files GC
over ~K launches, while lazy-on-read expires anything you actually request immediately). It's how git's
`objects/` and browser caches lay out from the first entry.

**SQLite** would only win if you wanted the absolute-fastest sweep at very large N *and* preferred SQL
ergonomics; for a blob cache that rarely pays for its complexity (a ~650 KB store that can drift from the
files). Order of preference: `mtime` debounced + sharded → SQLite only as a last resort.
