// Spike (not part of the package build): persist per-entry cache access time — file `mtime` touch
// (option 1) vs an SQLite index. Run:  swift Benchmarks/CacheAccessPersistence.swift [entryCount accessCount]
//
// Both keep the timestamp where the sweep can read it across launches with no separate manifest:
//   - mtime: re-`setAttributes` the file's modification date on a hit; sweep `stat`s the directory.
//   - sqlite: UPSERT a row keyed by cache key; sweep is an indexed SELECT.
// We measure the hot path (recordAccess) and the bulk sweep, the two operations the cache actually runs.

import Foundation
import SQLite3

let arguments = CommandLine.arguments
let entryCount = arguments.count > 1 ? Int(arguments[1])! : 10_000
let accessCount = arguments.count > 2 ? Int(arguments[2])! : 100_000
let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

func seconds(_ body: () -> Void) -> Double {
    let clock = ContinuousClock()
    let elapsed = clock.measure(body)
    let (whole, atto) = elapsed.components
    return Double(whole) + Double(atto) / 1e18
}

// Right-align a string in a fixed-width column (avoids `%s`/`%d`, which corrupt String(format:) varargs).
func col(_ string: String, _ width: Int) -> String {
    string.count >= width ? string : String(repeating: " ", count: width - string.count) + string
}

func row(_ name: String, _ total: Double, ops: Int) {
    let nsPerOp = String(format: "%.1f", total / Double(ops) * 1e9)
    let opsPerSec = String(format: "%.0f", Double(ops) / total)
    let label = name.padding(toLength: 38, withPad: " ", startingAt: 0)
    print("  \(label)\(col(nsPerOp, 9)) ns/op   \(col(opsPerSec, 12)) ops/sec   (\(String(format: "%.3f", total))s)")
}

print("entries: \(entryCount)   accesses: \(accessCount)\n")

// MARK: - Option 1: file mtime

let fileManager = FileManager.default
let mtimeDir = fileManager.temporaryDirectory.appendingPathComponent("bench-mtime-\(UUID().uuidString)")
try! fileManager.createDirectory(at: mtimeDir, withIntermediateDirectories: true)

var paths: [String] = []
for index in 0..<entryCount {
    let url = mtimeDir.appendingPathComponent("entry-\(index)")
    fileManager.createFile(atPath: url.path, contents: Data("x".utf8))
    paths.append(url.path)
}
// Half the entries start "old" so the sweep actually collects expired ones.
let oldDate = Date(timeIntervalSinceNow: -10 * 24 * 60 * 60)
for index in stride(from: 0, to: entryCount, by: 2) {
    try! fileManager.setAttributes([.modificationDate: oldDate], ofItemAtPath: paths[index])
}

print("Option 1 — file mtime")
// Sweep first, while half the entries are still seeded "old", so it actually collects expired ones.
let mtimeCutoff = Date(timeIntervalSinceNow: -7 * 24 * 60 * 60)
var mtimeExpired = 0
let mtimeSweep = seconds {
    let urls = (try? fileManager.contentsOfDirectory(at: mtimeDir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
    for url in urls {
        if let date = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate, date < mtimeCutoff {
            mtimeExpired += 1
        }
    }
}
row("sweep (scan + stat \(entryCount))", mtimeSweep, ops: entryCount)
print("    swept \(mtimeExpired) expired")

// Debounce fast path: a read only `stat`s the mtime and decides not to re-touch (the common case).
let mtimeStat = seconds {
    for k in 0..<accessCount {
        _ = try? URL(fileURLWithPath: paths[k % entryCount]).resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }
}
row("recordAccess (debounced: stat only)", mtimeStat, ops: accessCount)

// Worst case: touch the mtime on every access (no debounce).
let mtimeRecord = seconds {
    for k in 0..<accessCount {
        try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: paths[k % entryCount])
    }
}
row("recordAccess (touch mtime, no debounce)", mtimeRecord, ops: accessCount)
print()

// MARK: - Option 2: SQLite index

let sqliteURL = fileManager.temporaryDirectory.appendingPathComponent("bench-\(UUID().uuidString).sqlite")
var database: OpaquePointer?
sqlite3_open(sqliteURL.path, &database)
sqlite3_exec(database, "PRAGMA journal_mode=WAL;", nil, nil, nil)
sqlite3_exec(database, "PRAGMA synchronous=NORMAL;", nil, nil, nil)
sqlite3_exec(database, "CREATE TABLE access(key TEXT PRIMARY KEY, ts REAL);", nil, nil, nil)
sqlite3_exec(database, "CREATE INDEX idx_ts ON access(ts);", nil, nil, nil)

sqlite3_exec(database, "BEGIN;", nil, nil, nil)
var seed: OpaquePointer?
sqlite3_prepare_v2(database, "INSERT INTO access(key, ts) VALUES (?, ?);", -1, &seed, nil)
for index in 0..<entryCount {
    let ts = index % 2 == 0 ? oldDate.timeIntervalSince1970 : Date().timeIntervalSince1970
    sqlite3_bind_text(seed, 1, "entry-\(index)", -1, SQLITE_TRANSIENT)
    sqlite3_bind_double(seed, 2, ts)
    sqlite3_step(seed)
    sqlite3_reset(seed)
}
sqlite3_finalize(seed)
sqlite3_exec(database, "COMMIT;", nil, nil, nil)

let upsertSQL = "INSERT INTO access(key, ts) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET ts = excluded.ts;"

print("Option 2 — SQLite index (WAL, synchronous=NORMAL)")
// Sweep first, while half the rows are still seeded "old".
var select: OpaquePointer?
sqlite3_prepare_v2(database, "SELECT key FROM access WHERE ts < ?;", -1, &select, nil)
var sqliteExpired = 0
let sqliteSweep = seconds {
    sqlite3_bind_double(select, 1, mtimeCutoff.timeIntervalSince1970)
    while sqlite3_step(select) == SQLITE_ROW { sqliteExpired += 1 }
    sqlite3_reset(select)
}
sqlite3_finalize(select)
row("sweep (indexed SELECT \(entryCount))", sqliteSweep, ops: entryCount)
print("    swept \(sqliteExpired) expired")

var upsert: OpaquePointer?
sqlite3_prepare_v2(database, upsertSQL, -1, &upsert, nil)
let sqliteRecordAuto = seconds {
    for k in 0..<accessCount {
        sqlite3_bind_text(upsert, 1, "entry-\(k % entryCount)", -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(upsert, 2, Date().timeIntervalSince1970)
        sqlite3_step(upsert)
        sqlite3_reset(upsert)
    }
}
row("recordAccess (UPSERT, autocommit)", sqliteRecordAuto, ops: accessCount)

let sqliteRecordBatched = seconds {
    sqlite3_exec(database, "BEGIN;", nil, nil, nil)
    for k in 0..<accessCount {
        sqlite3_bind_text(upsert, 1, "entry-\(k % entryCount)", -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(upsert, 2, Date().timeIntervalSince1970)
        sqlite3_step(upsert)
        sqlite3_reset(upsert)
    }
    sqlite3_exec(database, "COMMIT;", nil, nil, nil)
}
row("recordAccess (UPSERT, 1 transaction)", sqliteRecordBatched, ops: accessCount)
sqlite3_finalize(upsert)
print()

sqlite3_close(database)

// Footprint of the SQLite store (plus a -wal/-shm sidecar in use mid-session).
let sqliteBytes = ((try? fileManager.attributesOfItem(atPath: sqliteURL.path))?[.size] as? Int) ?? 0
print("SQLite db file: \(sqliteBytes / 1024) KB for \(entryCount) entries (+ a -wal/-shm sidecar). mtime adds 0 bytes.")

// MARK: - Sweep scaling: the sweep is the O(n) operation, so grow N to find where mtime spikes.

print("\nSweep scaling — total time to find expired (half the entries):\n")
print("  \(col("entries", 10))  \(col("mtime scan", 14))  \(col("sqlite SELECT", 14))")
for n in [10_000, 50_000, 100_000, 200_000] {
    // mtime: n real files, half seeded old.
    let dir = fileManager.temporaryDirectory.appendingPathComponent("sweep-\(n)-\(UUID().uuidString)")
    try! fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
    for index in 0..<n {
        let url = dir.appendingPathComponent("e-\(index)")
        fileManager.createFile(atPath: url.path, contents: nil)
        if index % 2 == 0 { try! fileManager.setAttributes([.modificationDate: oldDate], ofItemAtPath: url.path) }
    }
    let mtimeScan = seconds {
        let urls = (try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        var expired = 0
        for url in urls where (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate).flatMap({ $0 < mtimeCutoff }) == true { expired += 1 }
        _ = expired
    }
    try? fileManager.removeItem(at: dir)

    // sqlite: n rows, half old, indexed on ts.
    let dbURL = fileManager.temporaryDirectory.appendingPathComponent("sweep-\(n)-\(UUID().uuidString).sqlite")
    var db: OpaquePointer?
    sqlite3_open(dbURL.path, &db)
    sqlite3_exec(db, "CREATE TABLE access(key TEXT PRIMARY KEY, ts REAL); CREATE INDEX idx_ts ON access(ts);", nil, nil, nil)
    sqlite3_exec(db, "BEGIN;", nil, nil, nil)
    var ins: OpaquePointer?
    sqlite3_prepare_v2(db, "INSERT INTO access(key, ts) VALUES (?, ?);", -1, &ins, nil)
    for index in 0..<n {
        sqlite3_bind_text(ins, 1, "e-\(index)", -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(ins, 2, index % 2 == 0 ? oldDate.timeIntervalSince1970 : Date().timeIntervalSince1970)
        sqlite3_step(ins); sqlite3_reset(ins)
    }
    sqlite3_finalize(ins)
    sqlite3_exec(db, "COMMIT;", nil, nil, nil)
    var sel: OpaquePointer?
    sqlite3_prepare_v2(db, "SELECT key FROM access WHERE ts < ?;", -1, &sel, nil)
    let sqliteScan = seconds {
        sqlite3_bind_double(sel, 1, mtimeCutoff.timeIntervalSince1970)
        var expired = 0
        while sqlite3_step(sel) == SQLITE_ROW { expired += 1 }
        sqlite3_reset(sel)
    }
    sqlite3_finalize(sel)
    sqlite3_close(db)
    try? fileManager.removeItem(at: dbURL)

    print("  \(col(String(n), 10))  \(col(String(format: "%.1f", mtimeScan * 1000), 11)) ms  \(col(String(format: "%.1f", sqliteScan * 1000), 11)) ms")
}

try? fileManager.removeItem(at: mtimeDir)
try? fileManager.removeItem(at: sqliteURL)
