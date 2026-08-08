# Roamly — App Overview

## What it is

Roamly is a cross-platform **Flutter** app (package name `roamly`, project directory `been`) that turns the geotagged photos already sitting in a user's photo library into a browsable travel history: which countries and cities they've been to, and when. Tagline from the pubspec: *"Roamly — countries and cities from your geotagged photos."*

It does one thing: scan the on-device photo library for images with embedded GPS coordinates, reverse-geocode those coordinates into place names, group consecutive same-place photos into "stays," and present the result as a nested list of **Country → City → Visit (date range + photo count)**.

Everything happens **on-device**. There is no backend, no account system, no network sync, and no photo upload — the iOS permission string spells this out explicitly: *"Roamly reads where your photos were taken (embedded location and dates) to show countries and cities you have visited. Photos stay on your device."*

## Platforms

It's a standard Flutter multi-platform project with generated targets for **iOS, Android, macOS, Windows, Linux, and Web**, though the core value (reading a device photo library with GPS metadata) is really an iOS/Android/macOS use case. Android manifest requests `READ_MEDIA_IMAGES`, `READ_EXTERNAL_STORAGE` (legacy, capped at SDK 32), and `ACCESS_MEDIA_LOCATION`.

## Core dependencies

- **`photo_manager`** — reads the native photo library (asset listing, GPS lat/lng per asset, permission handling, including iOS/Android "limited access" states).
- **`geocoding`** — reverse-geocodes lat/lng into `Placemark` data (country, administrative area, locality, sub-administrative area).
- **`intl`** — date formatting for visit ranges.

## How the pipeline works

The flow is a straight line from raw photo library → structured trip data, split across `lib/services/`:

1. **`PhotoScanService.collectGeoTaggedPhotos`** (`lib/services/photo_scan_service.dart`)
   Pages through the entire image library in batches of 250 via `photo_manager`, reads each asset's `latLng` (falling back to the async accessor when needed), and keeps only photos that actually have coordinates. Emits progress callbacks (`assetsProcessed`/`totalAssets`/`geoTagged`) so the UI can show a live counter.

2. **`PlaceResolver.resolve`** (`lib/services/place_resolver.dart`)
   Reverse-geocodes each `(lat, lng)` pair to a `ResolvedPlace {countryCode, countryName, cityDisplayName}` using the `geocoding` package. Results are cached in-memory keyed by coordinates rounded to 4 decimal places (~11m precision) so repeat/nearby photos don't re-hit the geocoder. Falls back to `"Unknown"` on geocoding failure or empty results.
   City name picking prefers `locality`, then `subAdministrativeArea` (skipping US "County"/"Parish" labels), then `administrativeArea`.

3. **NYC special-casing** (`lib/services/nyc_geography.dart`)
   New York City gets bespoke handling: a photo is classified as NYC only if it's in the US, the state normalizes to `NY`, and the county is one of the five boroughs (`New York`, `Kings`, `Queens`, `Bronx`, `Richmond`) — or, absent county data, the locality is literally one of the five borough names. This deliberately keeps New Jersey towns (e.g. East Rutherford / Bergen County) from ever being misclassified as NYC. Includes a full US state name → abbreviation lookup table so "New York" (spelled out) still resolves correctly.

4. **`VisitBuilder.buildFromPhotos`** (`lib/services/visit_builder.dart`)
   - Resolves a place for every photo (progress-reported).
   - Sorts all tagged photos chronologically.
   - Walks the sorted list and merges consecutive photos into a `VisitSegment` as long as they're in the *same canonical city* (`ResolvedPlace.rollupKey` = uppercase country code + lowercase city name) **and** the gap between consecutive photos is **≤ 14 days** (`maxGapDays`). A larger gap or a place change starts a new segment — this is how "one trip" vs. "two separate trips to the same city" gets distinguished.
   - Rolls segments up into `CountrySummary` → `CitySummary` → `VisitSegment` list, sorted alphabetically by country then city, with segments within a city sorted most-recent-first.

## Data models (`lib/models/`)

- `GeoPhoto` — raw photo id + timestamp + coordinates.
- `ResolvedPlace` — country code/name + city display name, with a `rollupKey` used for same-city comparisons.
- `TaggedPhoto` — a `GeoPhoto` paired with its `ResolvedPlace`.
- `VisitSegment` — one continuous stay: place, start/end datetime, photo count.
- `CitySummary` — a city name + its list of visit segments (i.e. separate trips there).
- `CountrySummary` — a country + its list of `CitySummary`, with a computed `totalPhotos`.

## UI (`lib/screens/home_screen.dart`)

Single-screen app (`HomeScreen`), backed by `photo_manager`'s permission APIs:

- **Permission gate**: on launch (and on app resume, via `WidgetsBindingObserver`), checks photo permission state. If not granted, shows a "No trips yet" empty state with buttons to request access or open OS settings.
- **Limited access banner**: if the OS grants "limited" photo access (iOS selective photo permissions), a persistent banner explains results are partial.
- **Scan flow** (triggered by an app-bar refresh icon or an in-body button): runs `PhotoScanService` then `VisitBuilder`, showing a two-phase progress UI — first "Finding geotagged photos… N (X / Y)", then "Looking up places… X / Y" — each with a `LinearProgressIndicator`.
- **Empty states**: distinct messaging for "haven't scanned yet," "no geotagged photos found," and "no photo permission."
- **Results view**: a scrollable list of expandable `ExpansionTile`s — one per country (avatar = 2-letter country code, subtitle = city/photo counts), expanding to per-city tiles, expanding further to individual visit rows showing a human-formatted date range (`"Aug 3, 2025"`, `"Aug 3 – 9, 2025"`, or `"Aug 3, 2024 – Jan 2, 2025"` depending on same-day/same-year/cross-year) and photo count.

## Theming (`lib/theme/roamly_theme.dart`)

A custom Material 3 theme (`buildRoamlyTheme`) built from a small brand palette (`RoamlyPalette`: deep slate, soft sand, muted teal, sky blue, warm orange, light gray) — an earthy/travel-adjacent color scheme. A `RoamlyExtraColors` `ThemeExtension` supplies a few semantic colors (`travelHighlight`, `visitedMarker`, `secondaryUi`) accessed via a `context.roamlyExtra` extension getter, used for icons and the country-avatar background.

## Permissions plumbing (`lib/photo_permission.dart`)

Defines `kPhotoPermissionOption`, a shared `PermissionRequestOption` requesting image access with `mediaLocation: true` on Android — required on many Android builds to actually read GPS EXIF data from photos, not just the images themselves.

## Tests (`test/`)

- `nyc_geography_test.dart` — unit tests for the NYC/NJ borough-vs-county classification logic and state-name normalization.
- `widget_test.dart` — default Flutter widget test scaffold (largely boilerplate).

## Project status

This is an early-stage / MVP-scale personal project (no `.git` repo initialized yet in this working directory, default README still says "A new Flutter project," version `1.0.0+1`). The architecture is small and clean: 4 service files, 4 model files, 1 screen, 1 theme file — no state management library, no persistence layer (every scan is re-computed live from the photo library each time), no networking beyond the OS-level geocoding calls.
