---
title: Lexicon development
status: ready
---

## Purpose

Add local Lexicon authoring and compatibility analysis after read-only schema
resolution has established a trusted inspection path.

## Commands

~~~text
ocaat lexicon list <nsid>
ocaat lexicon parse <path>...
ocaat lexicon validate <uri-or-path>
ocaat lexicon lint [<file-or-directory>]...
ocaat lexicon status [<file-or-directory>]...
ocaat lexicon breaking [<file-or-directory>]...
ocaat lexicon diff <from> <to>
ocaat lexicon check-dns [<file-or-directory>]...
ocaat lexicon pull <nsid-pattern>...
ocaat lexicon new <nsid>
ocaat lexicon publish <path>...
ocaat lexicon unpublish <nsid>...
~~~

## Requirements

- Local parsing and diagnostics report file, path, and line information.
- Compatibility tools distinguish additive, compatible, and breaking changes.
- Pull and generated files use explicit output paths and no-overwrite behavior.
- Publish and unpublish require explicit auth, target summary, and confirmation.
- Reuse the resolver source and validation constraints from Lexicon reads.

## Verification

Test against Tempest official and smoke Lexicon fixtures plus invalid documents,
DNS failures, and compatibility-change fixtures.

## Subsequent planned work

Generated typed client code is a separate product decision and is not implied by
Lexicon analysis.
