# Benchmark: persisting cache access time — file `mtime` vs SQLite

A spike to decide how the disk cache should persist per-entry *last access* (for the sliding TTL /
warm-cold expiry) across launches, **without a separate manifest** that can drift from the files.

Two co-located approaches were compared:

- **Option 1 — file `mtime`.** Re-`setAttributes` the file's modification date on a hit; the sweep
  `stat`s the cache directory. The timestamp lives *on* the file — nothing separate to sync.
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

### Sweep scaling — where `mtime` spikes

The sweep is the O(n) operation (it must `stat` every file), so it's the one that blows up as the cache
grows. SQLite answers it with an indexed range query instead:

| entries | `mtime` scan | SQLite `SELECT` |
|--:|--:|--:|
| 10,000 | 39 ms | 0.9 ms |
| 50,000 | 215 ms | 7 ms |
| 100,000 | 471 ms | 12 ms |
| 200,000 | **1,388 ms** | 26 ms |

At 200k entries the `mtime` sweep is **~1.4 s** vs SQLite's 26 ms — ~50×. The hot path, by contrast,
barely moves with N (per-op), so the *only* place scale hurts is the sweep.

## Reading it

- **Hot path (the one that matters — runs on every cache read):** `mtime` touch (26 µs) and SQLite
  autocommit (31 µs) are **comparable** — both are bound by per-op durability, not the data structure.
  Debouncing the `mtime` touch (only re-touch when it's already stale) drops the common read to a bare
  `stat` (~15 µs here, and that's inflated by `URL.resourceValues`; a raw `stat` is cheaper). SQLite only
  wins the hot path if you **batch** writes in a transaction (1.5 µs) — but batching means buffering
  access updates and flushing later, which adds a crash-loss window and a flush policy. For the cache's
  bookkeeping that complexity isn't worth it.
- **Sweep:** here's the real divergence. The `mtime` scan grows with total entries — fine at 10k (~39 ms)
  but a **0.5 s spike at 100k and ~1.4 s at 200k**, since it must `stat` every file. SQLite's indexed
  `SELECT` stays in the tens of ms. The sweep runs once per launch on a background task, so single-digit
  hundreds of ms is tolerable — but a multi-second launch-time scan at 100k+ entries is not. So the answer
  genuinely depends on cache size: below ~tens of thousands, `mtime` is fine; past ~100k, the indexed
  query earns its keep.
- **Footprint & complexity:** `mtime` adds zero storage and zero moving parts; the timestamp can't drift
  from the file. SQLite adds a ~650 KB DB (+ WAL sidecars), the C-API plumbing, and — crucially — a
  *second store to keep in sync with the files*, which is exactly the manifest problem we set out to avoid.

## Recommendation

**Option 1 — `mtime`, debounced — for this cache's profile** (an image/blob cache, typically hundreds to
low-thousands of entries). It ties SQLite on the hot path, is zero-dependency, zero-footprint, and
self-syncing (no second store to drift). At those sizes the sweep is single-digit-to-tens of ms.

**But the scaling table makes the boundary explicit:** the `mtime` sweep spikes to ~0.5 s at 100k entries
and ~1.4 s at 200k. If a consumer routinely caches that many items (a long TTL over a media-heavy app),
the once-per-launch scan becomes a real cost and the indexed query wins. The escape hatch that *doesn't*
adopt SQLite: shard the cache directory and sweep one shard per launch (amortize the O(n) scan), or cap
the entry count. Reach for SQLite only if neither fits and 100k+ entries are the norm.
