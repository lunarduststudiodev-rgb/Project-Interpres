# Project Interpres

An experimental translation layer for opening Mac apps on iPadOS without a
virtual machine.

Apple Silicon Mac apps and iPadOS apps share a CPU and a binary format, so
Interpres loads the Mac binary directly into an iPadOS host app and supplies
the Mac frameworks iPadOS lacks (mainly AppKit) as shims built on UIKit.

## Status

Milestone 0: the host app builds in CI with built-in JIT support (StikJIT helper extension, pairing file import, and deep-link triggers).

| # | Milestone |
|---|---|
| 0 | Host app and CI pipeline (Built-in JIT & triggers) |
| 1 | Loader: a Mac command-line binary runs in an in-app console |
| 2 | AppKit core: a test Mac app shows a working window |
| 3 | AppKit breadth: nibs, menus, drawing, text, tables |
| 4 | Import any `.app` and report what it is missing |
| 5 | First real apps |

## JIT Support

A Mac binary needs executable memory that iPadOS blocks by default without an attached debugger. Interpres includes:
1. **Built-in StikJIT Helper (like Henge)**: An embedded app extension (`InterpresJITHelper.appex`) powered by StikJIT that enables JIT on-device over LocalDevVPN using an imported pairing file, without switching apps.
2. **External Triggers**: Deep-link URL handoffs to StikDebug (`stikjit://`), SideStore (`sidestore://`), and TrollStore (`apple-magnifier://`).

## Limits

- Needs sideloading and JIT. It cannot ship on the App Store.
- iPadOS blocks child processes, so Electron apps and browsers are out of reach.
- Apple Silicon binaries only.

## Install

Download `Interpres-ipa` from the latest run of the Build workflow, unzip it,
and sideload `Interpres.ipa` with SideStore or AltStore.

## Build

CI builds on a macOS runner. Locally, on a Mac with Xcode and xcodegen:

    bash ios/scripts/fetch_deps.sh
    xcodegen generate
    open Interpres.xcodeproj
