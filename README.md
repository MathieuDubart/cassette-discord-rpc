# cassette-discord-rpc

A macOS daemon that displays [Cassette](https://github.com/MathieuDubart/Cassette) playback as Discord Rich Presence.

## Prerequisites

- [Cassette](https://github.com/MathieuDubart/Cassette) — the macOS music player that broadcasts playback notifications
- Discord desktop app running on the same machine
- A Discord application with a valid `client_id` (create one at [discord.com/developers](https://discord.com/developers/applications))
- Swift 6+ toolchain (`swift --version`)

## Installation

### 1. Build

```sh
swift build -c release
```

### 2. Copy the binary

```sh
sudo cp .build/release/CassetteDiscordRPC /usr/local/bin/cassette-discord-rpc
```

### 3. Create the configuration file

```sh
mkdir -p ~/.config/cassette-discord-rpc
```

Create `~/.config/cassette-discord-rpc/config.json` with your Discord application's client ID:

```json
{
  "clientId": "YOUR_DISCORD_CLIENT_ID"
}
```

> See the [Configuration](#configuration) section below for details.

### 4. Install and load the LaunchAgent

```sh
cp Resources/fr.mathieu-dubart.cassette-discord-rpc.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/fr.mathieu-dubart.cassette-discord-rpc.plist
```

The daemon will now start automatically at login.

### Uninstall

```sh
launchctl unload ~/Library/LaunchAgents/fr.mathieu-dubart.cassette-discord-rpc.plist
rm ~/Library/LaunchAgents/fr.mathieu-dubart.cassette-discord-rpc.plist
sudo rm /usr/local/bin/cassette-discord-rpc
rm -rf ~/.config/cassette-discord-rpc
```

## Configuration

The daemon reads a single JSON file at startup:

**`~/.config/cassette-discord-rpc/config.json`**

```json
{
  "clientId": "YOUR_DISCORD_CLIENT_ID"
}
```

| Key        | Description                                                                 |
|------------|-----------------------------------------------------------------------------|
| `clientId` | The **Client ID** from your Discord Developer Portal application. Required. |

If the file is missing or malformed, the daemon logs a clear error and exits — it will never crash silently.

### Getting a Discord Client ID

1. Go to [discord.com/developers/applications](https://discord.com/developers/applications)
2. Create a new application (or use an existing one)
3. Copy the **Application ID** — this is your `clientId`

## Logs

The daemon uses `os.Logger` (subsystem `fr.mathieu-dubart.cassette-discord-rpc`). View logs with:

```sh
log stream --predicate 'subsystem == "fr.mathieu-dubart.cassette-discord-rpc"'
```

Or check the LaunchAgent output files:

```sh
tail -f /tmp/cassette-discord-rpc.log
tail -f /tmp/cassette-discord-rpc.err
```

## How it works

1. Cassette broadcasts `NSDistributedNotification` events when tracks change or playback stops
2. cassette-discord-rpc listens for these notifications and fetches cover art from [MusicBrainz](https://musicbrainz.org) / [Cover Art Archive](https://coverartarchive.org)
3. The daemon connects to the Discord desktop app via its local Unix socket IPC and updates your Rich Presence
