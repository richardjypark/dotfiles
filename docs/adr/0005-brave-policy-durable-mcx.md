# The Brave TorDisabled policy is written to the local MCX record

`/Library/Managed Preferences` is a cache that macOS rebuilds at login and reboot, so a direct plist write there can disappear. `run_after_41-setup-brave-policy.sh` writes the policy to the local Directory Services `MCXSettings` record with `dscl . -mcxset` and then refreshes, so the record is the durable source. When chezmoi runs through `sudo`, the script still targets `SUDO_USER`, the login user whose Brave profile is managed. See also the `brave-tor-policy-hardening` skill.
