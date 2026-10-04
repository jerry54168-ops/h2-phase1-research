# USER_SPACE_EQUIVALENT_CONTRACT_R1

STATUS = PROPOSED_FOR_REVIEW
EFFECTIVE = NO

## Purpose

Define a strict alternative to impossible/unsupported claims of exact-host pinning on GitHub-hosted runners.

`USER_SPACE_EQUIVALENT` means:

> The exact host machine is NOT claimed to be pinned.
> Instead, the execution Gate binds the user-space/runtime/tool/workflow/evidence identities that are material to the Phase 1 check, while preserving provider-observed host metadata as evidence rather than as a frozen host guarantee.

## Required bound identities

Before runtime:
- static candidate package SHA
- derived executable workflow SHA
- exact workflow file SHA
- exact PowerShell supply identity
- exact .NET supply identity
- exact action revisions
- exact synthetic input SHA
- exact receipt schema SHA
- exact repository identity
- exact runner class/label
- expected provider metadata fields
- artifact retention setting
- credential/permission mechanism
- NO_PAID_USAGE admission rule

At runtime:
- observed runner image/version metadata
- observed OS/kernel/runtime metadata
- observed PowerShell and .NET same-process identity
- run/job/check-run IDs
- actual artifact digests/hashes

## Explicitly NOT claimed

This contract must never claim:
- immutable exact GitHub host identity;
- frozen hardware identity;
- that `ubuntu-*` is an immutable host pin;
- that provider metadata equals a cryptographic host attestation;
- that user-space equivalence is Production qualification.

## Admission

If the future Gate cannot bind every required user-space identity, HOLD before workflow dispatch.

If provider-observed actual values violate the accepted equivalence predicates, HOLD.

## Effect

Even if satisfied, this contract supports only Phase 1 environment capability evidence.

It does not authorize H2 construction, Qualification Complete, or Production Ready.
