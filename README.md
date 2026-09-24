# BuffResponder 🙏✨

BuffResponder is a lightweight World of Warcraft Classic addon that sends a configurable thank-you whisper after another player buffs you.

## Supported clients 🎮

One Classic build supports:

- World of Warcraft Classic Era
- Classic Hardcore
- Season of Discovery

The current package targets Classic Era client `1.15.9` with interface `11509`.

## Features 🎯

- 💬 Up to five configurable response messages
- 🎲 Random or fixed-message selection
- ⏱ Configurable reply delay and per-player cooldown
- 🛡 Group and guild exclusions enabled by default
- 🌍 Realm-safe player identity handling
- 🔁 Buff application and refresh detection
- 🧪 Local self-test that never whispers another player
- 🔍 Optional diagnostic output

## Installation 📦

1. Close World of Warcraft.
2. Copy the `BuffResponder` folder into `_classic_era_/Interface/AddOns/`.
3. Start Classic Era, Hardcore, or Season of Discovery.
4. Enable **BuffResponder** in the character-select **AddOns** menu.
5. Enter the world and type `/buffr status`.

## Commands ⌨️

| Command | Description |
|---|---|
| `/buffr` or `/buffr help` | Show in-game help |
| `/buffr status` | Show the current configuration |
| `/buffr on` | Enable automatic replies |
| `/buffr off` | Disable replies and cancel pending replies |
| `/buffr message TEXT` | Set message 1 |
| `/buffr message1 TEXT` … `/buffr message5 TEXT` | Set a specific message |
| `/buffr message1` … `/buffr message5` | Clear a specific message |
| `/buffr mode random` | Randomly choose a non-empty message |
| `/buffr mode 1` … `/buffr mode 5` | Prefer one message, falling back to the first non-empty message |
| `/buffr delay 4` | Set reply delay from 0 to 30 seconds |
| `/buffr cooldown 60` | Set per-player cooldown from 0 to 3600 seconds |
| `/buffr excludegroup on\|off` | Toggle party and raid exclusion |
| `/buffr excludeguild on\|off` | Toggle guild exclusion |
| `/buffr debug on\|off` | Toggle diagnostic messages |
| `/buffr test` | Run local checks without sending a whisper |
| `/buffr reset` | Restore defaults and cancel pending replies |

## Default behavior ⚙️

- Automatic replies are enabled.
- A response waits 4 seconds.
- Each player has a 60-second cooldown after a reply.
- Group and guild members are excluded.
- A random non-empty response is selected.
- Buff tracking waits 8 seconds after entering the world to ignore login and zoning aura noise.
- Pending replies are cancelled when zoning, disabling the addon, or resetting settings.
- Every condition is checked again immediately before a whisper is sent.

## Recognized buffs ✨

The whitelist uses spell IDs and is independent of the game language. All Classic ranks and listed group variants are included for:

- Mark of the Wild and Gift of the Wild
- Thorns
- Arcane Intellect and Arcane Brilliance
- Blessing and Greater Blessing of Might
- Blessing and Greater Blessing of Kings
- Blessing and Greater Blessing of Wisdom
- Power Word: Fortitude and Prayer of Fortitude
- Unending Breath

## Privacy and anti-spam 🛡️

BuffResponder sends automated whispers when enabled. It does not read incoming whispers, communicate through addon channels, download data, or execute chat content.

To reduce unwanted messages, the addon:

- ignores self-applied and non-player buffs;
- ignores unsupported spells;
- excludes group and guild members by default;
- deduplicates pending replies;
- applies a per-player cooldown;
- preserves full `Name-Realm` identities; and
- cancels stale replies across world transitions.

Use `/buffr off` whenever automatic communication is not appropriate.

## Troubleshooting 🔧

### No reply is sent

1. Run `/buffr status` and confirm the addon is enabled.
2. Check whether the sender is excluded as a group or guild member.
3. Wait for the cooldown and the 8-second world-entry grace period.
4. Run `/buffr test`.
5. Enable `/buffr debug on`, reproduce the buff, and inspect the blue diagnostic output.

### The addon is marked out of date

The Classic interface number changes with game patches. Update the `## Interface` value in `BuffResponder.toc` to the value required by the installed Classic Era client, then validate the addon before release.

## Development tests 🧪

The packaged addon still contains exactly four runtime Lua files. `qa/run.lua` is an external mocked-WoW harness and is not listed in the addon manifest.

With a Lua 5.1-compatible interpreter installed, run:

```cmd
lua qa\run.lua
```

The harness checks settings migration and validation, identity normalization, slash commands, buff filtering, group and guild exclusions, timer cancellation, delayed send revalidation, and cooldown expiry.

## Release smoke test ✅

Run this checklist separately on Classic Era, Hardcore, and Season of Discovery:

- [ ] The addon loads without Lua errors.
- [ ] `/buffr`, `/buffr status`, and `/buffr test` render correctly.
- [ ] Reloading preserves valid settings and repairs malformed saved values.
- [ ] A supported external player buff schedules one response.
- [ ] Unsupported, self-applied, and non-player buffs send nothing.
- [ ] Party, raid, and guild exclusions work when enabled.
- [ ] Full cross-realm names are used for whisper targets and cooldowns.
- [ ] Repeated buffs produce only one pending response.
- [ ] Cooldown blocks another response until it expires.
- [ ] Disabling, resetting, or zoning cancels pending responses.
- [ ] Changing exclusions during the delay prevents a now-invalid response.
- [ ] No normal-mode diagnostic spam appears.

## Project page 🔗

[BuffResponder on CurseForge](https://www.curseforge.com/wow/addons/buffresponder)
