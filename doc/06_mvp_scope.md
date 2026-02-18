# 06_mvp_scope.md

## Purpose of the MVP

The goal of the Minimum Viable Product (MVP) is to launch CarbonFeet as
quickly as possible with a focused, high-impact feature set.

The MVP should: - Deliver immediate value to users - Validate
product-market fit - Test engagement and retention - Prove that
tracking + projections drive awareness and behavior change

This first version is intentionally narrow and prioritizes simplicity,
clarity, and speed of development.

## MVP Design Principles

The MVP must:

-   Be simple to understand within seconds
-   Provide visible personal insight
-   Show progress over time
-   Require minimal input effort
-   Focus on the most impactful emission categories

The MVP is not about completeness.\
It is about creating a strong core experience.

## Core MVP Features

### 1) Account System

Required for: - Multi-device sync - Secure personal data storage -
Future social features

**Included:** - Email registration & login - Basic profile: - Country -
Age group / life stage (simple selection)

**Not included (later):** - Apple login - Google login - Social features

------------------------------------------------------------------------

### 2) Onboarding Questionnaire

Goal: Create a baseline estimate quickly.

**Collected during onboarding:**

-   Country
-   Diet profile:
    -   Meat frequency per week
    -   Dairy consumption level
-   Car usage:
    -   Vehicle make/model
    -   Distance estimate (km/day OR km/year)
-   Home energy:
    -   Yearly electricity usage (kWh)
    -   Yearly gas usage (m³)
    -   If unknown → guided estimate

This creates the initial yearly projection.

------------------------------------------------------------------------

### 3) Dashboard (Home Screen)

The central screen of the product.

**Must show:**

-   CO₂ emitted this year (primary metric)
-   End-of-year projection
-   Pie chart per category:
    -   Flights
    -   Car
    -   Diet
    -   Energy
-   Green vs red zone:
    -   Compared to country average
    -   Compared to personal target
-   Trend chart (year-to-date progress)

This screen should communicate the user's situation within 5 seconds.

------------------------------------------------------------------------

### 4) CO₂ Posts (Event Logging)

Users can add impact events via a "+" button.

**Included categories:**

#### Flights

-   Input:
    -   Flight number
    -   Date
    -   Flight occupancy estimate:
        -   Nearly empty
        -   Half full
        -   Nearly full
-   System calculates:
    -   Distance
    -   Stops
    -   Aircraft type (if available)
    -   Individual emission estimate

If flight cannot be found → cannot be added (MVP constraint).

#### Car Usage

-   User selects:
    -   Vehicle make/model
-   User enters:
    -   Km/day OR km/year
-   System estimates yearly emissions

Users can update values anytime.

#### Diet

-   Set via onboarding
-   Editable anytime
-   Changes immediately affect projections

#### Home Energy

-   Yearly values
-   Editable anytime
-   Estimate mode available if unknown

------------------------------------------------------------------------

### 5) Projection Engine (Core Differentiator)

The MVP must continuously calculate:

-   Expected CO₂ footprint by end of year
-   Based on:
    -   Current logged data
    -   Baseline lifestyle inputs

Projection must update instantly when: - A flight is added - Car
distance changes - Diet is updated - Energy values change

This is a core motivation mechanism.

------------------------------------------------------------------------

### 6) Comparison System

Provide context to the user.

**Included comparisons:** - Country average emissions - Personal target
(baseline goal)

Visualized through: - Green zone (below reference) - Red zone (above
reference) - Simple indicators: - "Below average" - "Above average"

------------------------------------------------------------------------

### 7) Achievements (Lightweight)

Motivational layer.

**Included badge types:** - Improvement badge: - When projection drops
significantly - Consistency badge: - When user logs data regularly - Low
footprint badge: - When user is below country average

Badges must be: - Minimalistic - Positive - Non-gamified in a childish
way

------------------------------------------------------------------------

### 8) Simple Simulator (MVP-Light)

Allow basic "what-if" exploration.

Examples: - Remove one flight - Reduce car usage slightly - Reduce meat
consumption

Output: - New projected end-of-year CO₂ - Difference shown clearly

This helps users see that behavior changes matter.

------------------------------------------------------------------------

## Explicitly Out of Scope (Post-MVP)

These features are intentionally excluded from the first release:

### Social Layer

-   Friends
-   Leaderboards
-   Sharing profiles
-   Comparisons between users

### Integrations

-   Airline account imports
-   Bank integrations
-   Energy provider APIs

### Expanded Tracking

-   Purchases/consumption
-   Public transport
-   AI usage tracking

### Advanced Accuracy Features

-   Deep scientific models
-   Detailed lifecycle calculations

### Authentication Expansions

-   Apple login
-   Google login

------------------------------------------------------------------------

## MVP Success Criteria

The MVP is successful if:

-   Users understand their footprint quickly
-   Users return weekly
-   Users log major events (especially flights)
-   Users check their projection
-   Users become more aware of their impact

The primary success metric is: Awareness creation and engagement.

------------------------------------------------------------------------

## Development Strategy

The MVP should be built to:

-   Launch fast
-   Validate the concept
-   Be easily extendable

Key priorities: 1) Stability 2) Clear UX 3) Reliable projections 4)
Simple logging

Everything else can evolve later.
