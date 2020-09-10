# Unreleased

## Added

- Added `flush_callback` parameter to the creation of a store, to register
  a callback before a flush. This callback can be temporarily disabled by
  `~no_callback:()` to `flush`. (#189, #216)
- Added `Stats.merge_durations` to list the duration of the last 10 merges.
  (#193)
- Added `is_merging` to detect if a merge is running. (#192)
- New `IO.Header.{get,set}` functions to read and write the file headers
  atomically (#175, #204, @icristescu, @CraigFe, @samoht)
- Added a `throttle` configuration option to select the strategy to use
  when the cache are full and an async merge is already in progress. The
  current behavior is the (default) [`Block_writes] strategy. The new
  [`Overcommit_memory] does not block but continue to fill the cache instead.
  (#209, @samoht)

## Changed

- `Index.close` will now abort an ongoing asynchronous merge operation, rather
  than waiting for it to finish. (#185)
- `sync` has to be called by the read-only instance to synchronise with the
  files on disk. (#175)
- Caching of `Index` instances is now explicit: `Index.Make` requires a cache
  implementation, and `Index.v` may be passed a cache to be used for instance
  sharing. The default behaviour is _not_ to share instances. (#188)
- Module `Key` does not require `hash_size` anymore; function `hash` now returns
  `int64` hashes and is required to be evenly distributed over 64 bits. (#222)

## Fixed

- Added values after a clear are found by read-only instances. (#168)
- Fix a race between `merge` and `sync` (#203, @samoht, @CraigFe)

# 1.2.1 (2020-06-24)

## Added

- Added `Index_unix.Syscalls`, a module exposing various Unix bindings for
  interacting with file-systems. (#176)

## Fixed

- Fail when `Index_unix.IO` file version number is not as expected. (#178)

- Fixed creation of an index when an empty `data` file exists. (#173)

# 1.2.0 (2020-02-25)

## Added

- Added `filter`, removing bindings depending on a predicate (#165)

## Changed

- Parameterise `Index.Make` over arbitrary mutex and thread implementations (and
  remove the obligation for `IO` to provide this functionality). (#160, #161)

# 1.1.0 (2019-12-21)

## Changed

- Improve the cooperativeness of the `merge` operation, allowing concurrent read
  operations to share CPU resources with ongoing merges. (#152)

- Improve speed of read operations for read-only instances. (#141)

## Removed

- Remove `force_merge` from `Index.S`, due to difficulties with guaranteeing
  sensible semantics to this function under MRSW access patterns. (#147, #150)

# 1.0.1 (2019-11-29)

## Added

- Provide a better CLI interface for the benchmarks (#130, #133)

## Fixed

- Fix a segmentation fault when using musl <= 1.1.20 by not allocating 64k-byte
  buffers on the thread stack (#132)
- Do not call `pwrite` with `len=0` (#131)
- Clear `log.mem` on `close` (#135)
- Load `log_async` on startup (#136)

# 1.0.0 (2019-11-14)

First stable release.
