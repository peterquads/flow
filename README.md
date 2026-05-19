# Flow

A tiny menu-bar time tracker for macOS. Type a task name, watch the timer run
in your menu bar, and review a clean dashboard whenever you want.

- Cream + charcoal aesthetic, Emilio serif numerals, monospace UI text
- One-keystroke task start / pause / end from the menu bar
- Day / Week / Month / Quarter dashboard with stacked bar chart and breakdown
- Right-click any breakdown row to retime an entry (calendar + inline time field)
- Manual entry sheet for time you tracked elsewhere
- One-file JSON store in `~/Library/Application Support/Flow/`
- CSV export of every closed interval
- No network. No analytics. No third-party dependencies.

## Install

Requires macOS 14+ and Xcode command-line tools (`xcode-select --install`).

```sh
git clone https://github.com/<you>/flow.git
cd flow
./scripts/build.sh
```

The script builds a release binary, assembles `Flow.app`, ad-hoc codesigns it,
and copies it to `/Applications`. By default it also installs a per-user
`LaunchAgent` so Flow runs at login. Skip the agent with:

```sh
FLOW_INSTALL_AGENT=0 ./scripts/build.sh
```

Pick a different install location with `FLOW_INSTALL_DIR=~/Applications`.

## Run

```sh
open /Applications/Flow.app
```

Look for a small `F` (or running timer) in your menu bar.

- **Left-click** the menu bar icon — open the quick-start popover
- **Right-click** — task menu (new / end / open dashboard / quit)
- **Option-click** — pause / resume the current task
- **Open dashboard** — full chart, breakdown, manual entry, CSV export, settings

## Keyboard

In the menu bar popover:

- `↩` start the typed task (or the highlighted suggestion)
- `Esc` close

In the manual entry / edit sheets:

- `↩` save
- `Esc` cancel

## Develop

```sh
swift build -c debug
swift run Flow
```

The source tree:

```
Sources/Flow/
  AppDelegate.swift        # menu bar item, popover, dashboard window
  AppStore.swift           # task / interval store, mutations, timer
  Aggregator (Chart.swift) # bucketing for chart + breakdown
  DashboardView.swift      # main window (live header + Equatable heavy section)
  MenuBarPanel.swift       # popover content
  ManualEntrySheet.swift   # add-entry sheet with reusable date picker
  EditEntrySheet.swift     # context-menu edit sheet
  CSVExport.swift          # save-panel + CSV serializer
  Persistence.swift        # atomic JSON read/write
  Formatters.swift         # cached DateFormatter instances
```

## Data

Stored at `~/Library/Application Support/Flow/store.json` — pretty-printed,
schema-versioned JSON. Delete it from inside the app (Settings → Clear all
data) or from Finder.

## License

[MIT](LICENSE)
