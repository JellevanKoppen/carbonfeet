# 09_emission_calculation_strategy.md

## Purpose

This document defines how CarbonFeet estimates personal CO₂ emissions.

It outlines the calculation philosophy, data sources, assumptions, and
estimation methods used across categories. The goal is to create
realistic, understandable, and consistent emission estimates without
requiring scientific-level precision.

The system prioritizes: - Simplicity - Consistency - Realistic personal
approximation - Fast recalculation for projections

## Guiding Principle

CarbonFeet is designed to be:

-   95% simple\
-   70% accurate

This means: - Estimates should feel realistic - Inputs should be
minimal - Calculations should be consistent - Users should understand
results without complexity

The platform provides **realistic indicators**, not academic
measurements.

## Core Calculation Model

The system combines two types of data:

1)  Baseline emissions
    -   Diet
    -   Car usage
    -   Home energy
2)  Event-based emissions
    -   Flights

Total footprint =\
Baseline yearly emissions + sum of event emissions

Projection =\
Current behavior extrapolated to year-end

------------------------------------------------------------------------

## Category 1 --- Flights

Flights are one of the highest-impact and most dynamic emission sources.

### Inputs

User provides: - Flight number - Flight date - Occupancy estimate: -
Nearly empty - Half full - Nearly full

System retrieves (via lookup/API): - Origin & destination airports -
Distance (km) - Number of flight segments (stops) - Aircraft type (if
available)

### Calculation Concept

Base model: - Emissions per passenger per km × distance

Adjusted by: - Number of takeoffs/landings (stops) - Aircraft efficiency
profile - Occupancy estimate

Occupancy logic (example conceptual weighting): - Nearly empty → higher
per-passenger share - Half full → neutral baseline - Nearly full → lower
per-passenger share

This creates a personalized estimate per flight.

### Storage

Each flight stores: - Calculated CO₂e - Distance - Segment count -
Aircraft type (if available)

This avoids recalculating repeatedly.

------------------------------------------------------------------------

## Category 2 --- Car Usage

Car emissions are treated as a continuous yearly baseline.

### Inputs

User provides: - Vehicle make/model - Distance: - Km/day OR - Km/year

### Calculation Concept

Estimate yearly emissions using:

-   Vehicle-specific emissions factor (g CO₂/km)
-   Multiplied by yearly distance

If km/day is used: - Convert to yearly distance automatically

Future improvements (not MVP): - Fuel type - Electric vehicle logic -
Hybrid models

------------------------------------------------------------------------

## Category 3 --- Diet

Diet is estimated using a behavioral profile.

### Inputs

-   Meat frequency (days per week)
-   Dairy consumption level

### Calculation Concept

Assign a weekly emission estimate based on: - Meat consumption level -
Dairy consumption level

Convert to yearly emissions contribution.

The goal is not precision but realistic lifestyle approximation.

### Update Behavior

When the diet profile changes: - The baseline estimate is recalculated -
Projection adjusts immediately

------------------------------------------------------------------------

## Category 4 --- Home Energy

Energy use is treated as a yearly baseline.

### Inputs

User provides: - Electricity usage (kWh/year) - Gas usage (m³/year)

If unknown: - Estimated values based on guided questions

### Calculation Concept

Use regional emission factors to estimate:

-   CO₂ per kWh
-   CO₂ per m³ gas

Multiply by yearly usage.

Country selection is important here, as energy mix differs per region.

------------------------------------------------------------------------

## Projection Engine

The projection system continuously estimates:

-   End-of-year emissions based on current data

### Basic Model (MVP)

Projection =\
Baseline yearly emissions\
+ Flights already logged\
+ Estimated future baseline continuation

This is a linear projection model for simplicity and speed.

### Recalculation Triggers

Projection updates when: - A flight is added - Car data changes - Diet
profile changes - Energy data changes

------------------------------------------------------------------------

## Category Breakdown

For the dashboard pie chart, the system calculates totals per category:

-   Flights total CO₂
-   Car total CO₂
-   Diet total CO₂
-   Energy total CO₂

These are aggregated values from: - Baseline contributions - Event
contributions

------------------------------------------------------------------------

## Comparison Calculations

The system provides context through reference points:

### Country Average

Stored values: - Average yearly emissions per person per country

Used to: - Place users in green/red zone - Provide simple comparison
messaging

### Personal Target

A simplified target value based on: - Country - Global sustainability
goals (future refinement)

------------------------------------------------------------------------

## Simulator Logic (MVP-Light)

The simulator temporarily adjusts inputs to show impact.

Examples: - Remove one flight - Reduce meat consumption - Reduce driving
distance

System recalculates: - New projection - Difference vs current projection

No permanent data changes unless user confirms.

------------------------------------------------------------------------

## Performance Considerations

To keep the app responsive:

-   Store calculated emissions per event
-   Maintain projection snapshots
-   Recalculate only when inputs change

Avoid full recalculation on every screen load.

------------------------------------------------------------------------

## Transparency Philosophy

The app focuses on: - Clear results - Simple explanations - Visible
impact

Detailed scientific sources are not required in MVP, but the model
should remain consistent and defensible for future expansion.
