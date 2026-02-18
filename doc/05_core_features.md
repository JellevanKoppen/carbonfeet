# 05_core_features.md

## Overview

CarbonFeet is built around one core idea:

> Treat personal CO₂ emissions like a trackable metric, similar to
> fitness or budgeting.

The product focuses on: - Simple input - Clear dashboards - Motivation
through progress - Realistic personal estimates

This document describes the core feature set, independent of MVP scope.

## Core Experience Loop

The main loop of the app is:

1)  User logs lifestyle events ("CO₂ posts")\
2)  App calculates impact in the background\
3)  Dashboard shows totals, breakdowns, trends, and projections\
4)  User sees progress vs goals and averages\
5)  User is motivated to improve and continues logging

## Feature 1 --- Dashboard (Home)

The dashboard is the product's center of gravity.

It should show, at a glance:

### A) Total Emissions (Year-to-Date)

-   Primary headline metric
-   Displayed as CO₂e (kg or ton)

### B) End-of-Year Projection

-   "If you continue like this, you will end at X"
-   Updated automatically as new data is logged

### C) Category Breakdown (Pie Chart)

-   Visual breakdown per category
-   Users immediately see what drives their footprint

### D) Green vs Red Zone

-   A visual threshold showing whether the user is:
    -   Below a reference (green)
    -   Above a reference (red)

The zone is driven by: - Country average - Personal target - Life-stage
target (future)

### E) Timeline / Trend Chart

Shows emissions over time: - This year so far - Optional: compare to
last year (later)

## Feature 2 --- CO₂ Posts (Event Logging)

Users add "posts" to represent behaviors with carbon impact.

Design requirements: - Fast to add - Minimal required inputs - Optional
detail for better estimates - Always includes "Estimate for me" options

### Core Categories (initial)

-   Flights
-   Car usage
-   Diet profile
-   Home energy

Future categories: - Consumption (purchases) - Public transport - AI
usage - Household/shared profiles

## Feature 3 --- Flights (High Accuracy + Simple Input)

Flights are a key differentiator.

**Input (user-facing):** - Flight number - Date - "How full was your
flight?" (3 options)

**Calculated (background):** - Route distance - Stopovers (extra
takeoff/landing segments) - Aircraft type (if available) - Allocation
per passenger adjusted by occupancy estimate

**UX requirement:** - User sees simple results: - Emissions per flight -
Total flight emissions this year - Contribution to projection

If a flight cannot be found via lookup, it is not addable in MVP.

## Feature 4 --- Car Usage (Accessible + Personalized)

Car tracking supports two user styles:

1)  "I know my km per day (or week)"
2)  "I know my km per year"

**Input:** - Vehicle make/model (dropdown selection) - Distance input
(km/day or km/year)

**Calculated:** - Emissions estimate based on vehicle profile and
distance - Optional: fuel type (future refinement)

**UX requirement:** - Minimal friction - Users can change their car or
update distance anytime

## Feature 5 --- Diet Profile (Onboarding + Editable)

Diet is tracked through a simple questionnaire, not daily logging.

**Onboarding inputs (examples):** - How many days per week do you eat
meat? - How much dairy do you consume? (low/medium/high)

**Calculated:** - Weekly estimate that contributes to yearly projection

**UX requirement:** - Always editable - Changes should update
projections immediately

## Feature 6 --- Home Energy (Yearly Input + Optional Estimate)

Energy is collected as yearly values.

**Inputs:** - Electricity usage (kWh/year) - Gas usage (m³/year) or
equivalent - Optional: solar panels yes/no (future) - If unknown: guided
estimate

**Calculated:** - A yearly baseline that contributes to footprint and
projection

## Feature 7 --- Projections (The "Progress Engine")

Projections are a core motivational feature.

CarbonFeet continuously estimates: - End-of-year emissions if behavior
continues - Delta vs targets and averages

This creates a feedback loop: - Log → projection moves → user sees
impact

## Feature 8 --- Simulator ("What If?")

Users can explore impact without committing to changes.

Examples: - "One less flight this year" - "One meat-free week" - "Drive
10% less per month"

Simulator design goals: - Simple and immediate - Shows delta in
end-of-year projection - Can translate changes into achievable actions

MVP can start as a minimal set of scenarios.

## Feature 9 --- Comparisons (Context)

CarbonFeet provides reference points:

-   Country average (key)
-   Personal target
-   Life-stage target (optional now, expandable later)

Comparisons are shown as: - A green/red zone - Simple labels (below
average / above average) - Clear deltas ("You are X above/below")

## Feature 10 --- Achievements & Motivation

Motivation features include:

### A) Badges for:

-   Low emissions (relative to reference)
-   Improvement over time
-   Consistency of logging

### B) Positive reinforcement

-   Small wins
-   Milestones
-   Visual celebration (minimalist, not childish)

### C) Gentle nudges

-   When new logs are expected (weekly usage pattern)
-   When user is drifting above projection/goal

## Feature 11 --- Accounts & Sync

Accounts support: - Multi-device sync - Cross-platform usage (Flutter +
backend) - Social features in future

MVP requirement: - Email login - Secure data storage - Basic profile
settings (country, life-stage)

## Future Social Layer (Post-MVP)

Planned later: - Friends - Sharing totals or categories - Leaderboards
(lowest footprint)

Privacy requirements: - Private profile option - Explicit sharing
controls

## Summary

CarbonFeet's core features center around: - Simple event logging -
Strong visual dashboards - Projections and progress feedback - Context
through averages and targets - Motivation through badges and improvement

The design philosophy is: Make it easy to start, satisfying to improve,
and motivating to continue.
