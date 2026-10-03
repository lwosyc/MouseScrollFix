# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[semantic versioning](https://semver.org/).

## [1.0.0] — 2026-10-03

First release.

### Added

- Menu bar app that keeps Natural scrolling on the trackpad while inverting every mouse
  macOS recognises: USB, 2.4 GHz receivers, Bluetooth, high-resolution and free-spinning
  wheels, Magic Mouse, vendor drivers.
- Stream classification from documented Quartz fields (`scrollPhase`, `momentumPhase`,
  `isContinuous`) with sticky gesture ownership, a 400 ms grace window and momentum
  tracking, so a trackpad gesture keeps one direction from `mayBegin` to the end of its
  inertia.
- Device inventory from the I/O Registry (no Input Monitoring, no device access) used as
  a policy input: with no external pointing device present, ambiguous pixel input is left
  untouched so the trackpad cannot be inverted by accident.
- Preference-aware inversion: works with the system Natural scrolling setting both on and
  off, and never writes that setting.
- English and Russian interface, following the system language with a manual override.
- Permission window on first launch explaining exactly what Accessibility is used for,
  with an "Open System Settings" button and a "Check again" action.
- Diagnostics: counters, tap latency via `CGGetEventTapList`, other active event taps and
  an opt-in in-memory trace exportable as JSON Lines.
- Headless diagnostics: `--dump-devices`, `--dump-status`, `--dump-policy`.
- Build tooling: `build-app.sh` (app bundle + ad-hoc signature), `make-dmg.sh`
  (compressed image with a drag-to-Applications window layout), `dmg-layout.py`
  (`.DS_Store` written directly, no Finder automation permission), `make-icon.swift`,
  `make-dmg-background.swift`, `dmg-add-background.sh`, `run-tests.sh`.
- 56 unit tests / 631 assertions covering classification, momentum ownership, policy,
  mutation ordering and localisation completeness.

### Known limitations

- No public API attributes a scroll event to a device, so per-device routing
  ("invert mouse A but not mouse B") is impossible. Classification is per stream.
- Magic Mouse is a touch surface and keeps natural scrolling by default (configurable).
- High-resolution wheels that emit pixel deltas without gesture phases are treated as a
  mouse by default; a conservative pass-through mode is one setting away.
- The DMG window background picture cannot be set without either a one-time manual step in
  Finder or granting a script permission to control Finder: the Carbon Alias Manager that
  produced background aliases is no longer available.
