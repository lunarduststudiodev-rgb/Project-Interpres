# Project Interpres

An experimental translation layer for opening Mac apps on iPadOS without a
virtual machine.

Apple Silicon Mac apps and iPadOS apps share a CPU and a binary format, so
Interpres loads the Mac binary directly into an iPadOS host app and supplies
the Mac frameworks iPadOS lacks (mainly AppKit) as shims built on UIKit.

## Status

Milestone 0: the host app builds in CI and reports whether JIT is on. Nothing
Mac runs yet.

| # | Milestone |
|---|---|
| 0 | Host app and CI pipeline |
| 1 | Loader: a Mac command-line binary runs in an in-app console |
| 2 | AppKit core: a test Mac app shows a working window |
| 3 | AppKit breadth: nibs, menus, drawing, text, tables |
| 4 | Import any `.app` and report what it is missing |
| 5 | First real apps |

## Limits

- Needs sideloading and JIT (StikDebug or SideStore). It cannot ship on the App Store.
- iPadOS blocks child processes, so Electron apps and browsers are out of reach.
- Apple Silicon binaries only.

## Install

Download `Interpres-ipa` from the latest run of the Build workflow, unzip it,
and sideload `Interpres.ipa` with SideStore or AltStore.

## Build

CI builds on a macOS runner. Locally, on a Mac with Xcode and xcodegen:

    xcodegen generate
    open Interpres.xcodeproj
