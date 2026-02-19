# 12_implementation_status_backlog.md

## Document purpose
This document is the current implementation snapshot and the actionable backlog for the CarbonFeet MVP.

Last updated: 2026-02-19

## Agent instruction (living document)
All agents working on this repository must treat this file as a living document.
After each meaningful implementation change, agents should update this file with:
1. What was implemented.
2. What changed in priority or scope.
3. What remains open in the backlog.

## 0) Latest update (2026-02-19)

### Implemented in this iteration
- Added explicit unauthorized/session-expired handling in remote state path:
  - introduced `RemoteStateUnauthorized` and mapped HTTP `401/403` responses to this dedicated exception in `HttpRemoteStateClient`.
  - preserved existing behavior where transient statuses map to `RemoteStateUnavailable` and non-auth non-transient statuses map to `RemoteStateRequestFailed`.
- Propagated session-expired semantics through repository results:
  - added `sessionExpired` result states for auth, flight post, and profile mutation flows.
  - `RemoteAppRepository` now clears active session on unauthorized hydrate/save failures and persists logged-out local state.
  - unauthorized commit attempts now roll back in-memory changes before forcing re-auth.
- Added shell/UI forced re-auth prompt path:
  - app shell now handles `sessionExpired` mutation outcomes by logging out and showing an explicit auth notice message.
  - auth screen renders a session notice banner so users understand why they were redirected to sign in.
- Expanded test coverage for unauthorized path behavior:
  - remote HTTP client tests now verify unauthorized mapping (`401/403`) separately from generic `4xx` request-failed behavior.
  - repository tests cover unauthorized hydrate handling, unauthorized register/save behavior, and rollback + logout semantics on unauthorized mutations.
  - widget test covers post-submission unauthorized flow forcing logout with visible re-auth prompt.
- Verified local quality gates with successful `flutter analyze` and `flutter test`.

### Priority and scope changes
- CF-P0-12 (explicit unauthorized/session-expired handling path) moved to done.
- TEST-11 scope expanded to include unauthorized mapping and forced re-auth outcomes.
- Slice A now centers on endpoint contract alignment and secure session/token lifecycle implementation.

### Remaining open focus
- Validate and finalize backend endpoint contract details for the HTTP remote client (auth model, payload envelope, status semantics).
- Add secure remote auth/session token handling (token lifecycle, restore, expiry).

## 1) Current implementation status

### 1.1 Product flows currently implemented

| Area | Status | Current implementation |
|---|---|---|
| Account entry | Implemented (prototype) | Email/password register + login with local state |
| Onboarding | Implemented | Country, life stage, diet profile, car profile, home energy inputs |
| Dashboard headline metrics | Implemented | Year-to-date CO2e + end-of-year projection |
| Category breakdown | Implemented | Flights/car/diet/energy pie chart with legend |
| Comparison context | Implemented | Country average and personal target with green/red indication |
| Trend view | Implemented | Year-to-date monthly trend chart |
| Achievements | Implemented (lightweight) | Improvement, consistency, low-footprint badges |
| CO2 posts | Implemented | Add flight, update car, update diet, update home energy |
| Simulator | Implemented (lightweight) | Remove one flight, drive 10% less, one less meat day/week |
| Recent flights dashboard module | Implemented | Recent flights list + flight detail bottom sheet |

### 1.2 Domain and calculation status

| Area | Status | Notes |
|---|---|---|
| Emissions summary engine | Implemented | Baseline + logged flights + YTD/projection/trend |
| Flight lookup constraint | Implemented | Unknown flight numbers are rejected in MVP |
| Flight occupancy effect | Implemented | Nearly empty / half full / nearly full multipliers |
| Energy estimation | Implemented | Country defaults applied when user selects estimate mode |
| Life-stage effect in equations | Not implemented | Collected in onboarding but not yet used by calculator |

### 1.3 Data and state management status

| Area | Status | Notes |
|---|---|---|
| Local persistence | Implemented | SharedPreferences state storage and hydration |
| Data model serialization | Implemented | JSON round-trip for user/profile/flights/activity |
| Multi-device sync | Partial | Remote repository path supports simulated and HTTP client implementations with explicit unauthorized/logout handling; backend contract hardening and secure token lifecycle are pending |
| Offline conflict strategy | Not implemented | No sync model exists yet |
| State architecture | Implemented (phase 1) | Code split into `lib/features/*`, `lib/domain/*`, `lib/data/*`; `main.dart` acts as app shell |
| Auth/user repository seam | Implemented (local + remote-ready) | Async result-based `AppRepository` contract with `LocalAppRepository` and `RemoteAppRepository` implementations |
| Emissions/post repository seam | Implemented (local + remote-ready) | Flight/car/diet/energy post mutations use async repository operations with unavailable/error statuses and rollback on commit failure |
| Persistence schema versioning | Implemented | Persisted payload includes `schemaVersion` with migration path for legacy payloads |

### 1.4 UX validation and safeguards status

| Area | Status | Notes |
|---|---|---|
| Auth input validation | Improved | Email format + stronger register password rules |
| Onboarding validation | Implemented (inline) | Car and energy ranges validated with field-level inline errors |
| Flight dialog validation | Implemented (inline) | Flight number/date validation shown inline in flight dialog |
| Duplicate flight protection | Implemented | Blocks same flight number on same date |
| Async submission loading/error handling | Implemented | Auth/post submissions expose in-flight UI, explicit failure feedback, retry actions for transient unavailable paths, and forced re-auth handling for unauthorized session expiry |
| Dashboard data quality guards | Implemented | Loading/empty/error states added for dashboard sections with malformed-data protection |
| Advanced edge-case handling | Partial | Plausibility rules improved, but not exhaustive yet |

### 1.5 Test coverage status

| Area | Status | Notes |
|---|---|---|
| Emission calculator unit tests | Implemented | Baseline/projection, occupancy effects, simulator, leap-year and year-boundary projection behavior |
| Persistence unit tests | Implemented | Persisted state round-trip coverage |
| Validation unit tests | Implemented | Password, car, energy, flight number/date validation |
| Local repository unit tests | Implemented | Covers unknown/duplicate flight outcomes, profile update activity logging, and projection recalculation after profile mutations |
| Core widget smoke test | Implemented | Register flow reaches onboarding |
| Dashboard widget tests | Implemented | Recent flights detail drill-down plus loading/error guard-state coverage |
| Post/simulator flow widget tests | Implemented | Flight known/unknown/duplicate flows, car/diet/energy post update flows, and simulator scenario/delta rendering are covered |
| Async submission state widget tests | Implemented | Auth submit loading state + post submission failure/loading feedback + retry action recovery are covered |
| Remote repository tests | Implemented | Success path, transient retry recovery, retry-exhausted rollback, HTTP client request/response behavior, and unauthorized forced-logout/session-expiry behavior are covered |
| CI pipeline checks | Implemented | GitHub Actions runs analyze + test on push/PR |
| Golden and integration tests | Not implemented | No visual regression or end-to-end suite yet |

## 2) What still needs to be done (gaps)

| Gap | Impact | Priority |
|---|---|---|
| Finalize HTTP remote endpoint contract | HTTP client implementation exists, but endpoint/auth/error contract must be aligned with production backend | P0 |
| Add secure remote auth/session strategy | Required for production-grade remote login lifecycle and credential safety | P0 |
| Flight provider abstraction (mock + real path) | Needed to move beyond hardcoded catalog | P1 |
| Richer dashboard analytics UX (tooltips/legends/tap states) | Improves usability and clarity | P1 |
| Achievement system redesign (event-driven) | Current heuristics are simplistic | P1 |
| Life-stage model integration in equations | Product inconsistency if left unused | P1 |
| Accessibility pass (contrast, semantics, text scaling) | Required for production quality | P1 |
| Localization/i18n | Needed for broader audience and country expansion | P2 |
| Additional categories and integrations | Planned post-MVP expansion | P3 |

## 3) Elaborate prioritized backlog

## P0: Foundation and production-readiness

| ID | Task | Deliverable / Acceptance criteria |
|---|---|---|
| CF-P0-01 | Modularize codebase | ✅ Done: code moved into `lib/features/*`, `lib/domain/*`, and `lib/data/*` (part-based modules) with app-shell composition in `main.dart` |
| CF-P0-02 | Introduce app state + repositories | ✅ Done (local seam): repository now owns auth/user plus flight and profile post mutations; backend implementations remain open |
| CF-P0-03 | Backend-ready auth seam | ✅ Done: async repository contract with local + remote-ready implementation path and explicit auth result states |
| CF-P0-04 | Harden persistence versioning | ✅ Done: persisted schema version + migration path for legacy payload |
| CF-P0-05 | Form error-state consistency | ✅ Done: auth/onboarding/flight/car/energy forms now use inline field errors and block invalid submission |
| CF-P0-06 | Dashboard data quality guards | ✅ Done: dashboard sections now handle loading/empty/error states and malformed summary payloads |
| CF-P0-07 | CI pipeline setup | ✅ Done: GitHub Actions workflow runs `flutter analyze` + `flutter test` on push/PR |
| CF-P0-08 | Regression-focused test expansion | ✅ Done: projection boundaries, flight/simulator flows, and car/diet/energy post widget-flow coverage completed |
| CF-P0-09 | Async backend submission UX | ✅ Done: auth and post submissions now show in-flight UI, disable conflicting actions, and surface unavailable-path errors |
| CF-P0-10 | Remote retry resilience | ✅ Done: retry/backoff policy for transient remote failures + post-level retry actions with coverage for success-after-retry and rollback-on-exhaustion |
| CF-P0-11 | Production HTTP remote client wiring | ✅ Done: `HttpRemoteStateClient` + transport abstraction + `--dart-define` app wiring with local fallback and unit coverage |
| CF-P0-12 | Unauthorized/session-expired handling path | ✅ Done: `401/403` mapped to explicit unauthorized error, repository-level forced logout semantics, and auth re-prompt UX with test coverage |

## P1: Product depth and user value

| ID | Task | Deliverable / Acceptance criteria |
|---|---|---|
| CF-P1-01 | Flight provider abstraction | Separate `FlightProvider`; maintain local mock catalog and add API integration point |
| CF-P1-02 | Flight history UX | Add complete flight history screen with filtering and detail navigation |
| CF-P1-03 | Flight correction flows | Allow edit/remove logged flights with projection recalculation |
| CF-P1-04 | Enhanced simulator | Add more scenarios and explain per-category delta contributions |
| CF-P1-05 | Achievement engine redesign | Event-driven badge unlock rules and clear badge criteria UI |
| CF-P1-06 | Trend chart interaction | Add labels/tooltips for month points and better readability |
| CF-P1-07 | Life-stage equation integration | Apply life-stage modifiers in calculator and test expected effects |
| CF-P1-08 | Motivation nudges | Add gentle nudges for inactivity or upward trend drift |

## P2: Quality, accessibility, and international readiness

| ID | Task | Deliverable / Acceptance criteria |
|---|---|---|
| CF-P2-01 | Accessibility audit | Pass semantics checks, large text behavior, and color contrast review |
| CF-P2-02 | i18n framework setup | Externalized strings and locale-aware number/date formatting |
| CF-P2-03 | Unit system options | User can switch between kg/ton and distance conventions where relevant |
| CF-P2-04 | Visual analytics improvements | More legible chart axes, legends, and compact mobile behavior |
| CF-P2-05 | Golden tests | Snapshot coverage for key layouts on phone and tablet breakpoints |

## P3: Expansion and post-MVP groundwork

| ID | Task | Deliverable / Acceptance criteria |
|---|---|---|
| CF-P3-01 | Social contract design | Data contracts and privacy model for future sharing/friends features |
| CF-P3-02 | Integration contract design | Contracts for airline import, bank, and energy provider integrations |
| CF-P3-03 | Expanded emission categories | Add framework for purchases/public transport/AI usage categories |
| CF-P3-04 | Telemetry hooks | Product analytics events for engagement and behavior-change validation |

## 4) Testing backlog detail

| ID | Test task | Scope |
|---|---|---|
| TEST-01 | Calculator internals | Direct unit tests for car/diet/energy functions and boundary values |
| TEST-02 | Projection boundaries | ✅ Covered in unit tests (year rollover + leap year behavior for YTD/projection) |
| TEST-03 | Flight-post widget tests | ✅ Covered: known/unknown/duplicate flow behavior and validation coverage |
| TEST-04 | Post-update recalculation tests | ✅ Covered in repository-driven unit tests for car/diet/energy profile updates |
| TEST-05 | Simulator widget tests | ✅ Covered: scenario list rendering and delta labels |
| TEST-06 | Dashboard interaction tests | ✅ Covered: recent flights detail drill-down + loading/error guarded state rendering |
| TEST-09 | Non-flight post widget tests | ✅ Covered: car/diet/energy post update flows mutate dashboard projection and category totals |
| TEST-10 | Async submission widgets | ✅ Covered: auth submitting state and post submission in-flight/error handling |
| TEST-11 | Remote repository behavior | ✅ Covered: simulated/HTTP remote client paths, retry behavior, unavailable rollback outcomes, and unauthorized forced-logout/session-expiry outcomes |
| TEST-07 | Golden tests | Dashboard and onboarding responsive snapshots |
| TEST-08 | Integration smoke tests | Register/login/onboarding/log flight/end-to-end summary check |

## 5) Suggested execution plan (next 3 delivery slices)

### Slice A (highest urgency)
1. Align `HttpRemoteStateClient` with backend contract (auth headers/tokens, payload envelope, non-2xx semantics, API versioning).
2. Add secure remote session/token lifecycle for auth (login, restore, expiry handling).
3. ✅ Done: explicit unauthorized/session-expired handling path (forced logout + re-auth prompt) on remote auth failures.

### Slice B
1. Implement flight provider abstraction and history management (CF-P1-01, CF-P1-02, CF-P1-03).
2. Integrate life-stage modifiers and retune related tests (CF-P1-07).
3. Improve simulator clarity and analytics UX (CF-P1-04, CF-P1-06).

### Slice C
1. Accessibility and i18n groundwork (CF-P2-01, CF-P2-02).
2. Golden/integration test layer (TEST-07, TEST-08).
3. Define contracts for post-MVP social/integration tracks (CF-P3-01, CF-P3-02).

## 6) Definition of done (DoD) for backlog items

A backlog item is considered done only if:
1. Behavior is implemented and manually verified.
2. Unit/widget tests are added or updated.
3. `flutter analyze` passes with zero issues.
4. `flutter test` passes.
5. Relevant docs are updated in `doc/`.
