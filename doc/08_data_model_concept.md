# 08_data_model_concept.md

## Purpose

This document describes the conceptual data model for CarbonFeet.

It is not a strict database schema, but a structured overview of the
core entities, relationships, and data responsibilities within the
system. This will help developers and AI agents understand how
information should be organized and how different parts of the app
interact.

The model is designed to be: - Simple - Extendable - Scalable - Suitable
for future features

## Core Design Principles

1)  User-centered data structure\
    All data connects back to a single user profile.

2)  Event-based tracking\
    Emissions are driven by events ("CO₂ posts") such as flights and
    lifestyle inputs.

3)  Baseline + Dynamic data\
    The system combines:

-   Baseline lifestyle data (diet, energy, car usage)
-   Event-based data (flights)

4)  Projection-driven architecture\
    All stored data contributes to one key output:

-   End-of-year emission projection

------------------------------------------------------------------------

## Main Entities

### 1) User

Represents a single individual account.

**Core fields:** - user_id - email - password_hash - country -
life_stage (optional simple category) - created_at - updated_at

**Relationships:** - Has one diet profile - Has one car profile - Has
one home energy profile - Has many flight entries - Has many
achievements - Has projection data

------------------------------------------------------------------------

### 2) Diet Profile

Represents the user's dietary habits baseline.

**Fields:** - user_id - meat_days_per_week - dairy_level
(low/medium/high) - last_updated

**Purpose:** - Contributes to yearly baseline emissions - Editable
anytime - Impacts projection immediately

------------------------------------------------------------------------

### 3) Car Profile

Represents personal car usage data.

**Fields:** - user_id - vehicle_make - vehicle_model - distance_mode
(per_day / per_year) - km_per_day (nullable) - km_per_year (nullable) -
last_updated

**Purpose:** - Generates a yearly emissions estimate - Contributes to
baseline + projection

------------------------------------------------------------------------

### 4) Home Energy Profile

Represents household energy consumption.

**Fields:** - user_id - electricity_kwh_per_year - gas_m3_per_year -
is_estimated (true/false) - last_updated

**Purpose:** - Provides yearly baseline emissions - Editable anytime -
Updates projections

------------------------------------------------------------------------

### 5) Flight Entry

Represents a logged flight event.

**Fields:** - flight_id - user_id - flight_number - flight_date -
occupancy_level: - nearly_empty - half_full - nearly_full

**Lookup-calculated fields (stored after calculation):** -
origin_airport - destination_airport - distance_km -
number_of_segments - aircraft_type (if available) -
calculated_emissions_co2e

**Purpose:** - Major variable emission contributor - Directly impacts
yearly totals + projection

------------------------------------------------------------------------

### 6) Projection Snapshot

Represents the system's calculated current projection.

**Fields:** - user_id - co2_emitted_year_to_date -
projected_co2_end_of_year - baseline_co2_estimate - last_calculated_at

**Purpose:** - Drives dashboard numbers - Updated whenever new data is
added or edited

------------------------------------------------------------------------

### 7) Category Totals

Represents breakdown for visualization (pie chart).

**Fields:** - user_id - flights_total_co2 - car_total_co2 -
diet_total_co2 - energy_total_co2 - last_updated

**Purpose:** - Feed dashboard breakdown - Provide insight into major
drivers

------------------------------------------------------------------------

### 8) Achievement

Represents motivational badges.

**Fields:** - achievement_id - user_id - type: - improvement -
consistency - low_footprint - awarded_at

**Purpose:** - Reinforce engagement - Provide progress feedback

------------------------------------------------------------------------

## Derived / Calculated Data (Not User Input)

These values are calculated and may be stored for performance:

-   Year-to-date emissions
-   End-of-year projection
-   Category totals
-   Delta vs country average
-   Delta vs personal target

These should be recalculated when: - A flight is added - A baseline
profile changes - A user updates lifestyle inputs

------------------------------------------------------------------------

## Relationships Overview

User ├── DietProfile (1:1) ├── CarProfile (1:1) ├── HomeEnergyProfile
(1:1) ├── FlightEntry (1:N) ├── ProjectionSnapshot (1:1) ├──
CategoryTotals (1:1) └── Achievement (1:N)

This structure allows: - Clean separation of data - Easy updates - Clear
projection logic

------------------------------------------------------------------------

## Future-Ready Extensions

The model is intentionally designed to support future additions without
breaking structure.

Potential future entities:

-   FriendConnection
-   LeaderboardStats
-   PurchaseEntry (consumption tracking)
-   PublicTransportEntry
-   AIUsageEntry
-   CompensationActions (tree planting, etc.)

These would follow the same event-based pattern as FlightEntry.

------------------------------------------------------------------------

## Data Update Flow (Conceptual)

1)  User adds/updates data\
2)  System recalculates:
    -   Category totals
    -   Year-to-date emissions
    -   End-of-year projection\
3)  Dashboard reads updated snapshot

This keeps the UI fast and responsive.

------------------------------------------------------------------------

## Data Retention Strategy (MVP)

-   Keep historical data up to 2 years
-   Allow future expansion later
-   Store timestamps for all entries

This supports trend analysis without overcomplicating early storage
needs.
