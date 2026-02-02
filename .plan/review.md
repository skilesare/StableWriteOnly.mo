# StableWriteOnly Library Review

**Date:** February 2026  
**Version Reviewed:** 0.1.1  
**Reviewer:** Code Review

---

## Executive Summary

StableWriteOnly is a well-designed library for append-only stable memory storage on the Internet Computer. The core architecture is sound, leveraging the Region API correctly. However, there are several issues ranging from minor documentation inconsistencies to potential runtime traps and memory safety concerns that should be addressed before production use.

**Risk Level:** Medium  
**Recommendation:** Address critical and high-priority issues before production deployment.

---

## Table of Contents

1. [Critical Issues](#critical-issues)
2. [High Priority Issues](#high-priority-issues)
3. [Medium Priority Issues](#medium-priority-issues)
4. [Low Priority Issues](#low-priority-issues)
5. [Architecture Observations](#architecture-observations)
6. [Documentation Issues](#documentation-issues)
7. [Testing Gaps](#testing-gaps)
8. [Recommendations](#recommendations)

---

## Critical Issues

### 1. `read()` and `readTyped()` Can Trap on Invalid Index

**Location:** `lib.mo` lines 305-330, 335-370

**Problem:** The `read()` and `readTyped()` functions do not validate that the requested index exists. For `#Managed` mode, `List.at()` will trap if the index is out of bounds. For `#Stable`/`#StableTyped` modes, reading from an invalid index will return garbage data (uninitialized memory or data from another item).

```motoko
public func read(x : Nat) : Blob {
  let x64 = Nat64.fromNat(x);
  let (offset, size) : (Nat64, Nat) = switch(store.items){
    case(#Managed(items)){
      let item = List.at<OffsetInfo>(items, x); // TRAPS if x >= size
      // ...
    };
    case(#Stable(items)){
      // No bounds check - reads garbage if x >= items.count
      let pos = RegionLib.loadNat64(items.indexRegion, x64 * elem_size);
      // ...
    };
```

**Impact:** Application crashes or silent data corruption.

**Fix:** Add bounds checking and return `?Blob` or `Result<Blob, ReadError>`:

```motoko
public func read(x : Nat) : ?Blob {
  let itemCount = switch(store.items) {
    case(#Managed(items)) List.size(items);
    case(#Stable(items)) Nat64.toNat(items.count);
    case(#StableTyped(items)) Nat64.toNat(items.count);
  };
  if (x >= itemCount) return null;
  // ... existing logic
}
```

### 2. No Atomicity Guarantee on Write

**Location:** `lib.mo` lines 215-300

**Problem:** The `_writeTyped()` function performs multiple operations that are not atomic:
1. Grows main region (if needed)
2. Adds index entry
3. Writes blob to region
4. Updates currentOffset

If the canister traps between steps 2 and 4 (e.g., due to instruction limit), the index will point to unwritten or partially written data.

**Impact:** Data corruption after trap during write.

**Mitigation:** This is inherent to the IC model, but could be partially addressed by:
- Writing the blob BEFORE updating the index
- Documenting this limitation clearly

### 3. Potential Integer Overflow in Index Calculation

**Location:** `lib.mo` lines 258, 282

**Problem:** For `#Stable` mode:
```motoko
let newIndex = (items.count * elem_size) + elem_size;
```

If `items.count` is very large, this multiplication could overflow. While unlikely to hit in practice (would require ~1.15 quintillion items), it's undefined behavior.

**Impact:** Unlikely but theoretically possible index corruption.

**Fix:** Use checked arithmetic or validate count doesn't exceed safe bounds.

---

## High Priority Issues

### 4. Index Region Has No Maximum Pages Limit

**Location:** `lib.mo` lines 256-290

**Problem:** The index region for `#Stable` and `#StableTyped` modes has no configurable maximum. It grows until `Region.grow()` fails. This could consume all available stable memory, leaving none for other purposes.

**Impact:** Unpredictable memory consumption; could starve other canisters or regions.

**Fix:** Add `maxIndexPages` to `InitArgs` and enforce it during index growth.

### 5. `updateMaxPages()` Only Allows Increases

**Location:** `lib.mo` lines 375-378

**Problem:** 
```motoko
public func updateMaxPages(x: Nat64) : () {
  if(x > store.maxPages){
    store.maxPages := x;
  };
};
```

This silently ignores attempts to decrease `maxPages`. Users might expect an error or the value to actually change.

**Impact:** Confusing API behavior; users can't enforce stricter limits.

**Fix:** Either allow decreases (if current usage permits) or return a `Result` indicating success/failure with reason.

### 6. `swap()` Leaks Old Region Memory

**Location:** `lib.mo` lines 384-390

**Problem:** When `swap()` is called, the old regions are replaced but their stable memory is never reclaimed. The IC does not garbage collect stable memory.

```motoko
public func swap(new_region : Region) : Stats {
  store := new_region;  // Old store's regions are now orphaned
  return stats();
};
```

**Impact:** Permanent stable memory leak. Each swap permanently consumes additional stable memory.

**Documentation:** This is mentioned in comments but should be emphasized in the API docs with potential byte cost estimates.

### 7. No Way to Query Maximum Capacity

**Problem:** Users cannot easily determine how many more items can be written before hitting `maxPages`. The `stats()` function provides `currentOffset` and `maxPages`, but calculating remaining capacity requires understanding internal page allocation.

**Fix:** Add a `remainingCapacity() : Nat64` function that returns bytes remaining.

---

## Medium Priority Issues

### 8. Inconsistent Error Handling for `#Stable` Mode with `writeTyped()`

**Location:** `lib.mo` lines 207-212

**Problem:** Calling `writeTyped()` on `#Stable` (not `#StableTyped`) storage silently stores the blob but discards the type information. The type is stored in memory but never persisted.

```motoko
case(#Stable(items)){
  // type_of parameter is ignored entirely
  RegionLib.storeNat64(items.indexRegion, items.count * elem_size + 0, lastOffset);
  RegionLib.storeNat64(items.indexRegion, items.count * elem_size + 8, newItemSize);
  // No type stored!
```

**Impact:** Silent data loss; type information is accepted but discarded.

**Fix:** Return `#err(#TypeNotSupported)` when `writeTyped()` is called on `#Stable` storage, or store types anyway.

### 9. Debug Print Statements in Production Code

**Location:** Multiple locations in `lib.mo`

**Problem:** Several `D.print()` calls exist in the main library:
- Line 232: `D.print("memory full " ...)`
- Line 262: `D.print("index full stable" ...)`
- Line 288: `D.print("index full stable typed" ...)`
- Line 341: `D.print("reading block in lib typed" ...)`
- Line 353-354: Multiple debug prints

**Impact:** Performance overhead; potentially leaking internal state in logs.

**Fix:** Remove or gate behind a debug flag.

### 10. `List` Used for `#Managed` Index is Inefficient for Large Datasets

**Location:** `lib.mo` lines 247-254, 308-311, 341-344

**Problem:** `List.at()` is O(n) for access. For archives with millions of entries, reading item #1,000,000 requires traversing all previous nodes.

**Impact:** Read performance degrades linearly with item count.

**Mitigation:** 
- Document that `#Managed` is not suitable for large datasets
- Consider using a different data structure (though this may conflict with stable variable serialization goals)

### 11. Type ID Overflow in `#StableTyped`

**Location:** `lib.mo` line 293

**Problem:**
```motoko
RegionLib.storeNat16(items.indexRegion, ..., Nat16.fromNat(this_type_of));
```

If `type_of > 65535`, `Nat16.fromNat()` will trap.

**Impact:** Application crash if user provides type ID > 65535.

**Fix:** Validate type_of range and return an error, or document the 65536 type limit.

---

## Low Priority Issues

### 12. Documentation Import Path Mismatch

**Location:** `lib.mo` line 19, `README.md` line 27

**Problem:** Documentation shows:
```motoko
import SW "mo:table-write-only";  // Wrong
```

But package is named `stable-write-only` in `mops.toml`.

**Fix:** Update to `import SW "mo:stable-write-only";`

### 13. Unused Variable in `_writeTyped()`

**Location:** `lib.mo` lines 237-240

**Problem:**
```motoko
let _thisOffSetInfo = {
  offset = lastOffset;
  size = Nat64.toNat(newItemSize);
};
```

This variable is created but never used.

**Fix:** Remove or use for debugging.

### 14. KiB Constant Name is Misleading

**Location:** `lib.mo` line 164

**Problem:**
```motoko
let KiB = 65536 : Nat64;
```

65536 bytes = 64 KiB, not 1 KiB. The constant represents the page size, not a kibibyte.

**Fix:** Rename to `PAGE_SIZE` or `BYTES_PER_PAGE`.

### 15. No Versioning in Stable Data Format

**Problem:** The `Region` type has no version field. If the serialization format needs to change in a future version, there's no way to migrate existing data.

**Fix:** Add a version field to the Region type for future compatibility.

---

## Architecture Observations

### Strengths

1. **Clean Separation of Concerns**: The three storage modes (`#Managed`, `#Stable`, `#StableTyped`) serve distinct use cases well.

2. **Class+ Pattern**: Correct implementation of the stable library pattern, allowing flexible initialization.

3. **Efficient Binary Storage**: Direct use of Region API for blob storage is the most efficient approach.

4. **Proper Region API Usage**: Correctly uses `mo:core/Region` instead of deprecated `ExperimentalStableMemory`.

5. **Good Error Types**: Clear distinction between `#MemoryFull`, `#IndexFull`, and `#TypeRequired`.

### Weaknesses

1. **No Delete/Compact**: True to the "write-only" name, but limits use cases. Archives that need to purge old data have no recourse.

2. **No Iteration API**: No way to iterate over items without knowing the count. Would be useful for migration/export.

3. **No Concurrent Write Safety**: Multiple async calls could interleave writes, potentially corrupting the index if not externally synchronized.

4. **Tight Coupling to Candid**: The library accepts/returns `Blob` which is expected to be Candid-encoded, but doesn't validate or enforce this.

---

## Documentation Issues

1. **README says "ALPHA and NOT VALIDATED"** but is published to mops - clarify status
2. **Swap behavior** needs clearer documentation about memory leakage
3. **Performance characteristics** of each mode should be documented
4. **Capacity limits** should be documented (max items per mode)
5. **Thread safety** (or lack thereof) should be documented

---

## Testing Gaps

1. **No edge case tests** for maximum capacity
2. **No tests** for reading invalid indices
3. **No tests** for type_of overflow in `#StableTyped`
4. **No upgrade tests** for `#Managed` mode (serialize/deserialize cycle)
5. **No performance benchmarks** documented
6. **No fuzz testing** of the write/read cycle

---

## Recommendations

### Before Production Use

1. **Add bounds checking** to `read()` and `readTyped()` - Critical
2. **Document write atomicity limitations** - Critical
3. **Add index region size limits** - High
4. **Remove or gate debug prints** - Medium
5. **Fix documentation import path** - Low

### Future Enhancements

1. Add `count()` method for total item count
2. Add `remainingCapacity()` method
3. Add iterator/stream API for bulk reads
4. Consider adding optional compression
5. Add data format versioning
6. Consider append-only log format with checksums for integrity verification

### Version Bump Checklist

Before releasing 1.0.0:
- [ ] Address all Critical issues
- [ ] Address all High priority issues
- [ ] Add comprehensive bounds checking
- [ ] Remove alpha warning from README
- [ ] Add performance documentation
- [ ] Add migration guide for breaking changes

---

## Summary Table

| Priority | Count | Status |
|----------|-------|--------|
| Critical | 3 | 🔴 Must Fix |
| High | 4 | 🟠 Should Fix |
| Medium | 4 | 🟡 Consider |
| Low | 4 | 🟢 Nice to Have |

---

*This review reflects the state of the library as of the review date. Some issues may have been addressed in subsequent versions.*
