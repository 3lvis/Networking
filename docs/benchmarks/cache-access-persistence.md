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
| **recordAccess** (hot path, per read) | 26.3 µs touch · **14.9 µs** debounced (stat only) | **30.8 µs** autocommit · 1.5 µs batched (1 txn) |
| **sweep** (once per launch, 10k entries) | 4.2 µs/entry — **~42 ms** | 0.1 µs/entry — **~1 ms** |
| **footprint** | **0 bytes** extra | ~650 KB db + `-wal`/`-shm` sidecar |
| **moving parts** | none (timestamp on the file) | schema, C-API plumbing, a second store that can drift |

## Reading it

- **Hot path (the one that matters — runs on every cache read):** `mtime` touch (26 µs) and SQLite
  autocommit (31 µs) are **comparable** — both are bound by per-op durability, not the data structure.
  Debouncing the `mtime` touch (only re-touch when it's already stale) drops the common read to a bare
  `stat` (~15 µs here, and that's inflated by `URL.resourceValues`; a raw `stat` is cheaper). SQLite only
  wins the hot path if you **batch** writes in a transaction (1.5 µs) — but batching means buffering
  access updates and flushing later, which adds a crash-loss window and a flush policy. For the cache's
  bookkeeping that complexity isn't worth it.
- **Sweep:** SQLite's indexed `SELECT` is ~40× faster and scales as O(log n). But the sweep runs **once
  per launch on a background task**, and 42 ms for 10k entries (≈420 ms for 100k) is fine there. It only
  becomes a problem at very large populations (100k+), which isn't this library's profile (an image/blob
  cache — typically hundreds to low thousands).
- **Footprint & complexity:** `mtime` adds zero storage and zero moving parts; the timestamp can't drift
  from the file. SQLite adds a ~650 KB DB (+ WAL sidecars), the C-API plumbing, and — crucially — a
  *second store to keep in sync with the files*, which is exactly the manifest problem we set out to avoid.

## Recommendation

**Option 1 — `mtime`, debounced.** It ties SQLite on the hot path, is zero-dependency and zero-footprint,
and is self-syncing. SQLite's only clear win (the sweep) is a rare background op that's already fast
enough at realistic cache sizes. SQLite would only pay off at very large entry counts where an O(n)
directory scan hurts — revisit only if that ever becomes this cache's reality.
