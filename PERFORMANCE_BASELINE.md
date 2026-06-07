# FırınNet Performance Baseline

## Environment

- Flutter: `3.35.4`
- Dart: `3.9.2`
- OS: `Microsoft Windows NT 10.0.26200.0`
- Device: `emulator-5554`
- Emulator model: `sdk_gphone64_x86_64`
- API level: `36`
- Build mode baseline: `debug`, `profile`
- Test date: `2026-06-07 15:14 +03:00`
- Report commit: `86ffcac`
- App code baseline measured: `a6302de`

## Build/Test Baseline

Wall-clock measurements from the pinned local Windows + Pixel 7 / API 36 setup.
These are baseline observations, not optimization targets.

| Command | Result | Duration |
|---|---:|---:|
| `flutter analyze` | PASS | ~1.2s reported by Flutter |
| `flutter test` | PASS, `1.233` tests | ~30.3s |
| `flutter build apk --debug` | PASS | ~11.0s |
| `flutter build apk --profile` | PASS | ~79.2s |
| `flutter build apk --release` | FAIL, signing not ready | ~5.9s |
| `flutter test test/golden` | PASS | ~5.1s |
| `patrol test -t patrol_test/app_smoke_test.dart -d emulator-5554` | PASS, `13/13` | ~34.6s |
| `patrol test -t patrol_test/guest_guard_empty_profile_smoke_test.dart -d emulator-5554` | PASS, `21/21` | ~33.9s |
| `patrol test -t patrol_test/cta_guard_settings_legal_smoke_test.dart -d emulator-5554` | PASS, `33/33` | ~38.3s |

## APK Size

- `build/app/outputs/flutter-apk/app-debug.apk`: `233,210,760` bytes
- Approximate size: `222.4 MiB`
- Split artifacts: none observed for this debug build; only `app-debug.apk` and checksum file were present
- Note: this is a debug APK baseline, not a release size baseline
- `build/app/outputs/flutter-apk/app-profile.apk`: `99,109,415` bytes
- Approximate size: `94.5 MiB`
- Split artifacts: none observed for the profile build; only `app-profile.apk` and checksum file were present
- Release artifact: not available yet because release signing is not configured

## Profile/Release Measurement

This sprint adds a profile-pass measurement to narrow the gap between debug
and user-facing runtime.

Observed comparison:

- Debug APK size: `233,210,760` bytes
- Profile APK size: `99,109,415` bytes
- Debug cold start: `10,779` ms
- Profile cold start: `1,646` ms
- Release build: not available; `android/key.properties` is missing

Interpretation:

- Profile APK is materially smaller than debug and starts much faster on the
  pinned emulator.
- Release signing must be configured before a true release APK/AAB baseline can
  be collected.
- No code changes were made for performance; this remains a measure-only
  baseline.

## App Startup

Cold-start measurement was taken after installing the debug APK on the same
emulator and launching with:

```powershell
adb -s emulator-5554 shell am start -W -S -n com.firinnet.firin_defter/.MainActivity
```

Observed result:

- `WaitTime`: `10779` ms
- `LaunchState`: `UNKNOWN (-1)`
- `Activity`: `com.firinnet.firin_defter/.MainActivity`
- `Complete`: yes

Profile cold-start measurement on the same emulator:

```powershell
adb -s emulator-5554 shell am start -W -S -n com.firinnet.firin_defter/.MainActivity
```

Observed result:

- `LaunchState`: `COLD`
- `TotalTime`: `1641` ms
- `WaitTime`: `1646` ms
- `Complete`: yes

Interpretation:

- Debug cold start is slow enough to notice, but this baseline is still
  measure-only.
- Profile cold start is much closer to the user-facing runtime picture and is
  the baseline to compare against future optimization work.
- The Patrol boot smoke confirmed the app reaches Feed and the main tabs on the
  same emulator without crash.

## Main Navigation Runtime

Patrol 01/02/03 all passed on the same Pixel 7 / Android 16 API 36 emulator.
That gives a practical runtime baseline for:

- Feed -> Gruplar -> Market -> İlanlar -> Panel -> Feed
- guest guard and empty-state navigations
- CTA/legal/profile fallback navigations

Qualitative observation:

- No visible crash or obvious freeze during tab switching in the smoke runs.
- Tab transitions felt acceptable in debug on the pinned emulator.
- Profile navigation sampling also reached Gruplar, Market, İlanlar, Panel and
  back to Feed through the live UI hierarchy without visible freeze.
- No profiler trace was collected in this sprint.

## Feed Runtime

Observed from the current smoke runs and code audit:

- Initial feed render completes and the inline composer is visible.
- Feed paging is bounded by a page size of `20`.
- Feed list items are keyed by `ValueKey(post.id)`.
- Manual observation on the emulator did not show visible jank during the smoke
  pass.

## Scroll/Jank Observations

No microbenchmark was collected. Manual observations:

- Feed scrolling was usable and did not show obvious hitching in the smoke
  session.
- The feed uses a `ScrollController` threshold listener for `loadMore()`, so
  sustained near-bottom scrolling is the main place to watch for repeated calls
  or hitching.
- No visible jank was observed on the pinned API 36 emulator during the smoke
  pass.

## Memory Observations

No profiler memory snapshot was taken. Risk audit notes:

- Feed and marketplace media use `CachedNetworkImage`.
- Video cards use `VideoPlayerController` plus `VisibilityDetector` and dispose
  controllers in `dispose()`.
- The main memory risk is media-heavy feed/cards on long scroll sessions, not a
  known leak from this baseline.

## Media Runtime Risks

- `SocialPostCard` renders `CachedNetworkImage` for post media.
- `MarketplaceListingCard` and `MarketplaceImageGallery` also rely on cached
  network images and fullscreen image pages.
- `SocialPostVideo` initializes `VideoPlayerController.networkUrl(...)`, pauses
  when not visible, and disposes controllers properly.
- If media-heavy feeds become long or more video posts are introduced, startup
  decode and scroll memory should be re-profiled in profile/release mode.

## Repository/Query Risks

Feed:

- `listPostsPage`, `listPostsByOwnerPage`, and `listPostsPageForFollowing`
  are paged and use `range(offset, offset + limit - 1)` with server-side
  filters.
- Each feed page also performs batched sidecar fetches for liked/saved/media
  state, so this is not an N+1 pattern, but it is multiple queries per page.

Groups:

- `listGroups` and `listPopular` are bounded reads.
- `listJoined` uses an `inFilter` set derived from the joined cache.
- Member/profile display uses RPC-backed batching instead of per-row profile
  fetches.

Market:

- `listPage` / `listFiltered` are limited and filtered server-side.
- Media and save sidecars are batched by listing id.
- Filter predicates are applied before the `limit`, so the query shape is
  predictable.

Jobs:

- `listActiveOffers` uses `limit(limit)` and `order('created_at')`.
- There is no obvious N+1 in the read path from this baseline.

## Current Bottlenecks

1. Debug cold start is the largest visible cost in this baseline.
2. Feed/media-heavy cards can be expensive because images and videos sit on the
   main scroll path.
3. Feed sidecar data (`likes`, `saves`, `media`) is batched but still adds extra
   round-trips per page.
4. The feed scroll listener can fire repeatedly near the bottom threshold if
   the notifier guard is not strict enough.

## Recommended Next Fixes

1. Re-measure cold start in profile/release mode before tuning code.
2. Profile feed scroll and media decode cost with a real profiler trace.
3. Consider whether feed sidecar queries can be merged further if network
   latency becomes visible.
4. Re-profile the image/video screens if media volume increases.

## Release Performance Verdict

This is a measure-only baseline. No optimization refactor was made in this
sprint.

- Release blocker today: no, not from this baseline alone.
- Advisory note: debug cold start is slow, but that is not a release verdict.
- Release signing is not ready yet, so a true release APK/AAB baseline was not
  collected.
- Next performance sprint should use profile/release measurements before any
  code changes.
