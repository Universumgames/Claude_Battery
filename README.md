# Claude Usage Menu Bar

A macOS menu bar app showing your claude.ai Pro/Max usage as a battery icon.

## What it does

- Shows a battery-style icon in the menu bar reflecting the more constrained of
  your session (5-hour) or weekly usage window (green > orange > red as it drains).
- Clicking it opens a menu with exact percentages left, and when each limit resets.
- Auto-refreshes every 90 seconds.
- Ships a desktop widget (small/medium) showing both windows — see
  [Desktop widget](#desktop-widget) below for a known limitation with local
  (non-notarized) builds before you go looking for it in the widget gallery.

## How it gets the data

There is no official public API for the claude.ai subscription usage limits, so this
app calls the same internal endpoint the claude.ai web app itself uses:

    GET https://claude.ai/api/organizations
    GET https://claude.ai/api/organizations/{orgId}/usage

authenticated with your `sessionKey` cookie (the same approach used by several
open-source browser extensions, e.g. sshnox/Claude-Usage-Tracker). Because this is
unofficial, Anthropic could change the response shape at any time, breaking this app.

## Signing in

Click the menu bar icon -> "Sign in". An embedded browser window opens showing
claude.ai's real login page (`Sources/ClaudeUsageMenuBar/SignInWindowController.swift`,
a `WKWebView`). Log in as normal — email/password, or an SSO provider like "Continue
with Google" (popup-based SSO windows are supported too). The moment claude.ai sets
its `sessionKey` cookie, the app grabs it and closes the window automatically — no
DevTools, no copy-paste.

The cookie is stored in your macOS Keychain, never anywhere else. It's long-lived but
will eventually expire (e.g. if you log out elsewhere) — just click "Sign in again" in
the menu to refresh it.

If the embedded browser ever misbehaves for your account, "Paste session cookie
manually" is still there as a fallback:

1. Log into https://claude.ai in your own browser.
2. Open DevTools -> Application (Chrome) or Storage (Firefox) -> Cookies -> claude.ai.
3. Copy the value of the `sessionKey` cookie and paste it into that dialog.

## Install via Homebrew

    brew tap Universumgames/tap
    brew install --cask claude-usage

The cask installs a prebuilt release from this repo's
[GitHub Releases](https://github.com/Universumgames/Claude_Battery/releases). That build
is signed with an Apple Development certificate, not notarized by Apple, so on some
Macs Gatekeeper may still call it "damaged" the first time — right-click the app in
`/Applications` and choose "Open" once if so.

To upgrade: `brew upgrade --cask claude-usage`. To uninstall: `brew uninstall --cask claude-usage`.

## Build & install

    make install

Regenerates the Xcode project, archives a Release build via `xcodebuild archive`,
signs and exports it via `xcodebuild -exportArchive` (using `ExportOptions.plist`,
same as Xcode's Organizer "Distribute App" flow), packages the result as
`Claude Usage.app`, and installs it to `/Applications` (killing any running
instance first so the copy isn't blocked).

    make run        # install, then launch it
    make app        # just build .build/Claude Usage.app, don't install
    make xcodeproj  # only regenerate the .xcodeproj from project.yml
    make uninstall  # stop it and remove it from /Applications
    make clean      # remove the .build directory

To launch at login, add `/Applications/Claude Usage.app` under
System Settings -> General -> Login Items.

## Desktop widget

The widget lives in a `ClaudeUsageWidgetExtension` target (`Sources/ClaudeUsageWidget`)
embedded in the app bundle. It doesn't talk to claude.ai itself — the always-running
menu bar app writes its latest fetch into a shared App Group container
(`group.de.universegame.ClaudeUsageMenuBar`, see `Sources/Shared/SharedUsageSnapshot.swift`)
and pokes `WidgetCenter` to redraw whenever it refreshes. If the widget shows
"Open Claude Usage to sign in", the app either isn't running or hasn't fetched yet.

**Signing:** both targets use `CODE_SIGN_STYLE: Automatic` with `DEVELOPMENT_TEAM: 98ZXK38P8L`
(this needs a real provisioning profile because of the App Groups entitlement — a bare
"Apple Development" certificate with manual signing isn't enough on its own). Make sure
that team's Apple ID is signed in under Xcode -> Settings -> Accounts; `-allowProvisioningUpdates`
then creates whatever profiles it needs automatically.

**Known limitation — the widget doesn't currently show up in the widget gallery.**
`make install` produces a correctly signed, correctly entitled app (verified with
`codesign` — matching `TeamIdentifier` and `application-groups` entitlement on both
the app and the widget's `.appex`), but `pluginkit` never registers the extension and
`spctl -a` reports the app as "rejected". This is because the app is only signed with
an "Apple Development" certificate — macOS only trusts app extensions (including
WidgetKit widgets) for discovery from apps that are notarized (Developer ID) or
Mac App Store-signed; a local development certificate doesn't clear that bar,
regardless of Debug/Release or plain-build/archive-export. Neither switching build
configuration nor moving to the archive+export flow above changed this. Two ways to
actually fix it, not yet done:
- Open `ClaudeUsageMenuBar.xcodeproj` in Xcode and hit Run (▶) once — Xcode's own
  install/launch path performs additional local trust registration that a plain
  `open` of the built `.app` skips.
- Set up notarization (needs a Developer ID Application certificate + an
  app-specific password or API key for `notarytool`), then staple the ticket —
  the actual sanctioned fix, appropriate if this app is ever distributed beyond
  this machine.

## Cutting a new Homebrew release

1. Bump `MARKETING_VERSION` in `project.yml` if needed, then `make app`.
2. Zip it: `ditto -c -k --sequesterRsrc --keepParent ".build/Claude Usage.app" ".build/Claude Usage.app.zip"`
3. `shasum -a 256 ".build/Claude Usage.app.zip"` for the sha256.
4. Tag and push: `git tag -a vX.Y.Z -m "Claude Usage vX.Y.Z" && git push github vX.Y.Z`
5. `gh release create vX.Y.Z ".build/Claude Usage.app.zip" -R Universumgames/Claude_Battery --title vX.Y.Z --notes "..."`
6. In the [homebrew-tap](https://github.com/Universumgames/homebrew-tap) repo, bump `version` and
   `sha256` in `Casks/claude-usage.rb` and push — GitHub replaces spaces in release asset
   filenames with dots (`Claude.Usage.app.zip`), which the cask URL already accounts for.

## Xcode project

The `.xcodeproj` is generated from `project.yml` via `xcodegen` (not hand-maintained).
`make app` / `make install` always regenerate it first, so newly added or removed
source files under `Sources/ClaudeUsageMenuBar` are picked up automatically — you
don't need to run `xcodegen` by hand. If you're working purely in Xcode and just
added a file there, it's already reflected on disk, so a re-open isn't needed either.

## App icon

The icon is an Icon Composer document at `Sources/ClaudeUsageMenuBar/AppIcon.icon`
(a background gradient + a battery glyph layer at `Assets/battery.svg`, with a
separate darker gradient for dark mode). It's a real Icon Composer file — open it
directly in Icon Composer (`open "Sources/ClaudeUsageMenuBar/AppIcon.icon"` or via
Xcode) to tweak colors, lighting, or add more layers interactively. Xcode compiles
it into the app icon automatically via `ASSETCATALOG_COMPILER_APPICON_NAME` in
`project.yml`, same as a traditional `.appiconset`.

    make foldericon

Renders that same icon (via Icon Composer's `ictool`) into `.build/FolderIcon.icns`
and `.build/FolderIcon.png` — flat images you can use as this project folder's
custom Finder icon: open the `.icns` in Preview, Cmd+A then Cmd+C, select this
folder in Finder, Cmd+I, click the small icon top-left of the Info panel, Cmd+V.
