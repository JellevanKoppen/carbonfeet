# 07_user_flow.md

## Purpose

This document describes how users move through CarbonFeet from first
launch to regular weekly usage.

It defines the primary navigation logic, screen order, and interaction
flow so that designers, developers, and AI agents understand the
intended user experience structure.

The goal is to keep flows simple, intuitive, and fast.

## Core Experience Philosophy

The user flow must feel:

-   Simple within seconds
-   Logical without explanation
-   Motivating immediately
-   Focused on insight and progress

The app should never feel complex or overwhelming.

## Primary Flow Overview

The main user journey consists of five phases:

1)  First Launch\
2)  Account Creation\
3)  Onboarding Setup\
4)  Dashboard Experience\
5)  Ongoing Weekly Usage

------------------------------------------------------------------------

## Phase 1 --- First Launch

### Entry Screen

User opens the app for the first time.

Goals of this screen: - Communicate what CarbonFeet does - Create
trust - Encourage quick signup

Suggested content: - Short tagline - 1--2 sentence explanation - CTA:
"Create Account"

User actions: - Create account - Log in (existing users)

------------------------------------------------------------------------

## Phase 2 --- Account Creation

### Required Fields (MVP)

-   Email
-   Password

Purpose: - Enable multi-device sync - Secure personal data - Prepare for
future social features

After account creation: → User is immediately guided into onboarding.

------------------------------------------------------------------------

## Phase 3 --- Onboarding Setup

The onboarding creates the initial baseline projection.

This phase should feel quick and guided.

### Step 1 --- Country Selection

Used for: - Average emission comparisons - Regional calculations

### Step 2 --- Diet Profile

Questions: - How many days per week do you eat meat? - How much dairy do
you consume? (low/medium/high)

Result: - Weekly dietary emission estimate

### Step 3 --- Car Usage

User selects: - Vehicle make/model

User enters: - Km per day OR - Km per year

Result: - Yearly car emission estimate

### Step 4 --- Home Energy

User enters (if known): - Electricity usage (kWh/year) - Gas usage
(m³/year)

If unknown: - Guided estimation questions

Result: - Yearly home energy baseline

### Step 5 --- Initial Projection

System calculates: - Estimated yearly CO₂ footprint - Initial category
breakdown

User sees their first insight: - Total projection - Pie chart - Initial
green/red zone position

This moment is important.\
It should create curiosity and awareness.

User proceeds to Dashboard.

------------------------------------------------------------------------

## Phase 4 --- Dashboard Experience (Core Screen)

This is the main screen users return to.

### Key Elements

1)  CO₂ This Year (primary metric)
2)  End-of-Year Projection
3)  Pie Chart (category breakdown)
4)  Green vs Red Zone indicator
5)  Trend chart (year progress)
6)  "+" button to add CO₂ post

This screen must answer instantly: - How am I doing? - Am I improving? -
Where does my footprint come from?

------------------------------------------------------------------------

## Phase 5 --- Adding CO₂ Posts

User taps "+" to add an event.

### Post Type Selection

Options (MVP): - Flight - Car update - Diet update - Energy update

------------------------------------------------------------------------

### Flight Flow

Inputs: - Flight number - Date - Occupancy estimate: - Nearly empty -
Half full - Nearly full

System does: - Lookup flight details - Calculate emissions - Update
totals and projection

User sees: - Impact added - Dashboard instantly updated

------------------------------------------------------------------------

### Car Update Flow

User can: - Change km/day OR km/year - Change vehicle (if needed)

System: - Recalculates yearly estimate - Updates projection immediately

------------------------------------------------------------------------

### Diet Update Flow

User adjusts: - Meat frequency - Dairy consumption

System: - Updates dietary baseline - Adjusts projection

------------------------------------------------------------------------

### Energy Update Flow

User can: - Update yearly values - Switch from estimate to actual data

System: - Recalculates baseline - Updates projection

------------------------------------------------------------------------

## Phase 6 --- Ongoing Weekly Behavior

Expected natural usage pattern:

-   User opens app weekly
-   Reviews dashboard
-   Adds major events (especially flights)
-   Watches projection change

The experience should create a loop:

1)  Log event\
2)  See projection move\
3)  Feel impact\
4)  Stay engaged

------------------------------------------------------------------------

## Phase 7 --- Achievements Trigger Flow

Badges appear when:

-   Projection drops significantly
-   User stays below average
-   User logs consistently

Presentation: - Subtle - Positive - Minimalistic

Goal: Reinforce progress without gamifying too aggressively.

------------------------------------------------------------------------

## Phase 8 --- Simulator Flow (MVP-Light)

User accesses a simple "What if?" tool.

Example actions: - Remove one flight - Reduce meat consumption - Drive
less

System shows: - New projected end-of-year total - Clear difference from
current path

Purpose: Make future choices feel tangible.

------------------------------------------------------------------------

## Long-Term Flow Extensions (Post-MVP)

Planned additions:

-   Friends & leaderboards
-   Social comparisons
-   Challenges
-   Data integrations

These will plug into the existing dashboard loop without changing the
core flow.

------------------------------------------------------------------------

## UX Priorities

The entire flow must optimize for:

-   Speed
-   Clarity
-   Minimal friction
-   Immediate feedback

Users should never need a tutorial to understand what to do next.
