# Secrets Management

This guide covers how to manage secrets in the chezmoi dotfiles repository.

## Current Approach: Untracked Environment Files

The repository uses untracked local files for sensitive values. This avoids committing secrets to git while keeping configuration flexible.

**Bootstrap private config:**
```
~/.config/dotfiles/bootstrap-private.env
```

This file is sourced by `bootstrap-omarchy.sh` and is never committed. Example contents:

```bash
TAILSCALE_AUTH_KEY=tskey-auth-xxxxx
GITHUB_TOKEN=ghp_xxxxx
```

## Optional: GPG Encryption with Chezmoi

For secrets that need to travel with the repo (API keys referenced in templates, etc.), chezmoi supports GPG-encrypted files.

### Setup

1. **Create or import a GPG key:**
   ```bash
   gpg --full-generate-key  # Create new key
   gpg --list-keys           # Find your key ID
   ```

2. **Configure chezmoi to use your key:**
   Add to `~/.config/chezmoi/chezmoi.toml`:
   ```toml
   encryption = "gpg"
   [gpg]
       recipient = "your-email@example.com"
   ```

3. **Add encrypted template data:**
   ```bash
   chezmoi add --encrypt ~/.config/dotfiles/secrets.toml
   ```
   This creates an encrypted file in the source directory that chezmoi decrypts on `apply`.

### Using Encrypted Data in Templates

Create an encrypted data file (e.g., `.chezmoidata/secrets.toml.age` or `.chezmoidata/secrets.toml.asc`):

```toml
[secrets]
api_key = "sk-xxxxx"
```

Reference in templates:
```
{{ .secrets.api_key }}
```

### Workflow

```bash
# Encrypt a file
chezmoi add --encrypt ~/path/to/secret-file

# Edit an encrypted file
chezmoi edit --encrypt ~/path/to/secret-file

# Re-encrypt after GPG key change
chezmoi re-add
```

## Best Practices

1. **Never commit plaintext secrets** to the repository
2. **Use untracked env files** (`bootstrap-private.env`) for deployment-specific secrets
3. **Use GPG encryption** only when secrets must travel with the repo
4. **Prefer environment variables** over files for runtime secrets
5. **Rotate secrets** if you suspect the GPG key or env file was compromised
6. **Add sensitive patterns to `.chezmoiignore`** to prevent accidental inclusion:
   ```
   *.env
   *credentials*
   *secret*
   ```

## Reference

- [Chezmoi encryption docs](https://www.chezmoi.io/user-guide/encryption/)
- [GPG quick start](https://www.chezmoi.io/user-guide/encryption/gpg/)
- [age encryption alternative](https://www.chezmoi.io/user-guide/encryption/age/)
