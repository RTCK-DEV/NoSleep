# NoSleep

[日本語版はこちら](README.ja.md)

A macOS menu bar app that toggles `caffeinate -dimsu` + `sudo pmset -a disablesleep 1`, and adjusts the Apple Silicon GPU memory limit (`iogpu.wired_limit_mb`) with a percentage slider.

![macOS](https://img.shields.io/badge/macOS-27%2B-black) ![License](https://img.shields.io/badge/license-MIT-green)

## Install

Download `NoSleep.zip` from [Releases](../../releases), unzip, and move `NoSleep.app` anywhere you like.

Since the app is ad-hoc signed, remove the quarantine flag after downloading:

```sh
xattr -d com.apple.quarantine NoSleep.app
open NoSleep.app
```

Or build from source:

```sh
./build.sh        # produces NoSleep.app
open NoSleep.app  # a coffee cup icon appears in the menu bar
```

## Usage

- **Enable Sleep Prevention** — starts `caffeinate -dimsu` and runs `sudo -n pmset -a disablesleep 1`
- **Disable Sleep Prevention** / quitting the app — kills `caffeinate` and restores `pmset -a disablesleep 0`
- **Change VRAM Allocation…** — pick a percentage (5–95%) of physical memory; runs `sudo sysctl iogpu.wired_limit_mb=<MB>`
  - Useful for increasing GPU memory for local LLMs on Apple Silicon
  - "Restore Default" sets it back to `0`. Resets automatically on restart

## sudoers setup (passwordless pmset / sysctl)

Choose **"Set Up Administrator Access…"** in the menu, or run:

```sh
sudo ./install-sudoers.sh
```

This adds NOPASSWD entries to `/etc/sudoers.d/nosleep-pmset` for only:

- `/usr/bin/pmset -a disablesleep 0` / `1`
- `/usr/sbin/sysctl iogpu.wired_limit_mb=*`

Without it, `caffeinate` still works (only the `pmset`/`sysctl` parts will warn).

## Localization

English and Japanese are supported. The app follows the system language.

## Uninstall

```sh
sudo rm /etc/sudoers.d/nosleep-pmset
sudo pmset -a disablesleep 0   # if still set to 1
rm -rf NoSleep.app
```
