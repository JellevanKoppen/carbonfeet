# 11_session_backlog.md

## Session context
- Date: 2026-02-18
- Goal: implement CarbonFeet MVP from product docs and leave a continuation-ready backlog.
- Scope implemented in code: `/Users/jellevankoppen/git/carbonfeet/lib/main.dart` and tests in `/Users/jellevankoppen/git/carbonfeet/test/widget_test.dart`.

## What was delivered this session

### A) Product flow implemented
- Account entry flow:
  - Email + password register
  - Email + password login
  - Local in-memory account store for MVP prototype
- Onboarding flow:
  - Country
  - Life stage
  - Diet profile (meat days + dairy)
  - Car profile (vehicle + km/day or km/year)
  - Home energy (known values or estimate mode)
- Dashboard flow:
  - Year-to-date CO2 metric
  - End-of-year projection metric
  - Category breakdown visualization (flights/car/diet/energy)
  - Green/red zone against country average + personal target
  - Year trend chart
  - Achievements area
  - Quick access to simulator
- CO2 posts flow:
  - Add flight
  - Update car
  - Update diet
  - Update home energy
- Simulator flow:
  - Remove one flight
  - Drive 10% less
  - One less meat day/week

### B) Domain model and calculation engine implemented
- In-app data model:
  - User
  - DietProfile
  - CarProfile
  - EnergyProfile
  - FlightEntry
  - ActivityEvent
- Calculation logic:
  - Baseline yearly emissions = car + diet + energy
  - Event emissions = flights
  - Year-to-date = prorated baseline + flights to date
  - End-of-year projection = baseline + current-year flights
  - Category totals and monthly trend
- Comparison logic:
  - Country average by selected country
  - Personal target by selected country
  - Below/above average label
- Achievement logic:
  - Improvement badge: >=5% lower than initial projection
  - Consistency badge: activity in >=3 distinct weeks
  - Low footprint badge: projected <= country average

### C) Flight MVP constraint implemented
- Flight entry is accepted only when flight number exists in local lookup table.
- Unknown flight number is rejected with feedback.
- Occupancy factor is included (`nearly_empty`, `half_full`, `nearly_full`).

### D) Engineering hygiene delivered
- Flutter app now builds from real MVP code (template removed).
- Static analysis passes (`flutter analyze`).
- Widget test updated to new flow and passes (`flutter test`).
- `.gitignore` replaced with comprehensive Flutter-oriented ignore rules.

## MVP coverage matrix (from docs vs implementation)

### Fully covered for prototype
- Account entry (email/password) as prototype UX.
- Onboarding baseline setup.
- Dashboard headline metrics.
- Category breakdown.
- Green/red comparison context.
- Trend visualization.
- CO2 posts for all 4 MVP categories.
- Instant projection recalculation after updates.
- Lightweight achievements.
- Lightweight simulator.

### Partially covered (intent delivered, production depth pending)
- Accounts and sync:
  - Current: in-memory account state only.
  - Missing: backend auth, secure storage, cross-device sync.
- Flight intelligence:
  - Current: local lookup table.
  - Missing: real lookup API and richer route/stop data.
- Trend and charting:
  - Current: custom simple chart painters.
  - Missing: richer chart UX/tooltips/accessibility.

### Not covered yet (deliberately deferred)
- Social features.
- External integrations.
- Expanded categories (consumption/public transport/AI usage).
- Advanced scientific modeling.

## Key assumptions made in this implementation
- Country reference values (average emissions, targets, electricity factors) are static in code.
- Vehicle emission factors are static per model in code.
- Diet model uses practical heuristics (not scientific precision).
- Projection model is linear baseline + logged flight events.
- Simulator is preview-only and does not persist scenario changes.

## Known limitations / technical debt
- Data is not persisted across app restarts.
- Password handling is plain in memory (prototype only).
- No backend or API abstractions yet.
- No localization/i18n.
- No explicit accessibility pass (semantics, large text behavior, color contrast audit).
- No form validation for advanced edge cases (extreme values, implausible ranges).
- Custom charts are intentionally lightweight and not feature-rich.

## Prioritized backlog for next session

### P0 (highest priority)
- [ ] Add local persistence (e.g. shared preferences or local DB) for user profile and logged posts.
- [ ] Split `main.dart` into feature modules:
  - `lib/features/auth/*`
  - `lib/features/onboarding/*`
  - `lib/features/dashboard/*`
  - `lib/domain/*`
- [ ] Introduce repository/service layer for emissions and user state.
- [ ] Add robust validation rules and user-facing error states for all forms.
- [ ] Add unit tests for emission calculations and simulator scenarios.

### P1
- [ ] Replace in-memory auth with real backend-ready auth abstraction.
- [ ] Add secure credential handling strategy and session management.
- [ ] Add flight data provider interface + mock + real implementation path.
- [ ] Add recent flights list and detail screen in dashboard.
- [ ] Improve achievement logic to be event-driven and less heuristic.

### P2
- [ ] Improve visual analytics (better chart components, legends, touch states).
- [ ] Add optional dark theme and accessibility-focused color adjustments.
- [ ] Add onboarding stepper UX with progress indicator and step validation.
- [ ] Add life-stage impact modifiers (currently collected but not used in equations).

### P3
- [ ] Prepare integration contracts for future social layer.
- [ ] Add offline-first conflict strategy for future sync.
- [ ] Add telemetry hooks for product validation metrics.

## Testing backlog
- [ ] Add unit tests for:
  - `EmissionCalculator._carYearlyKg`
  - `EmissionCalculator._dietYearlyKg`
  - `EmissionCalculator._energyYearlyKg`
  - flight occupancy multipliers
  - projection calculations around year boundaries
- [ ] Add widget tests for:
  - onboarding completion -> dashboard rendering
  - add flight known number vs unknown number behavior
  - car/diet/energy updates changing projection
  - simulator output labels
- [ ] Add golden tests for dashboard layout on phone + tablet breakpoints.

## Suggested immediate next-session execution order
1. Refactor code into modules first (to reduce future merge risk).
2. Add persistence and migrate current state model.
3. Add calculation unit tests and baseline snapshots.
4. Add backend/auth abstraction seams.
5. Expand flight provider beyond hardcoded catalog.

## File-level handoff map
- Main implementation:
  - `/Users/jellevankoppen/git/carbonfeet/lib/main.dart`
- Current widget test:
  - `/Users/jellevankoppen/git/carbonfeet/test/widget_test.dart`
- Ignore rules:
  - `/Users/jellevankoppen/git/carbonfeet/.gitignore`
- Product docs used for implementation:
  - `/Users/jellevankoppen/git/carbonfeet/doc/01_vision.md`
  - `/Users/jellevankoppen/git/carbonfeet/doc/02_problem_statement.md`
  - `/Users/jellevankoppen/git/carbonfeet/doc/03_product_philosophy.md`
  - `/Users/jellevankoppen/git/carbonfeet/doc/04_target_users.md`
  - `/Users/jellevankoppen/git/carbonfeet/doc/05_core_features.md`
  - `/Users/jellevankoppen/git/carbonfeet/doc/06_mvp_scope.md`
  - `/Users/jellevankoppen/git/carbonfeet/doc/07_user_flow.md`
  - `/Users/jellevankoppen/git/carbonfeet/doc/08_data_model_concept.md`
  - `/Users/jellevankoppen/git/carbonfeet/doc/09_emission_calculation_strategy.md`
  - `/Users/jellevankoppen/git/carbonfeet/doc/10_future_roadmap.md`

## Notes for future implementation consistency
- Keep the product tone motivating, not guilt-driven.
- Preserve fast data entry and visible projection feedback loop.
- Keep equations understandable and stable before adding accuracy complexity.
- Prefer expanding test coverage before adding many new feature branches.
