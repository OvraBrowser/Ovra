# Releasing Ovra

Updates are delivered with [Sparkle](https://sparkle-project.org). The feed is
`appcast.xml` on `main`, served by GitHub Pages at
`https://ovrabrowser.github.io/Ovra/appcast.xml`. Update zips are attached to
GitHub releases.

## One-time setup

### 1. Sparkle signing key
The EdDSA private key lives in the login keychain of the Mac that makes
releases. The matching public key is `SUPublicEDKey` in `Ovra/Info.plist`.
**If the private key is lost, installed copies can no longer be updated.**

Back it up (and keep the file out of this repo):

```sh
~/Library/Developer/Xcode/DerivedData/Ovra-*/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys -x ~/Desktop/ovra-sparkle-private-key
```

Restore on another Mac with `generate_keys -f <file>`.

### 2. Developer ID signing (paid team)
Without it, first installs show “Apple could not verify Ovra…” and need
right-click › Open.

Ovra ships on team `373V4B5FK8` (an **Individual** membership). On Individual
memberships only the Account Holder can create certificates — other members,
even Admins, never get *Certificates, Identifiers & Profiles* access. So:

1. The Account Holder, on their Mac: **Xcode › Settings › Apple Accounts ›
   the team › Manage Certificates… › + › Developer ID Application**.
2. Right-click the new certificate › **Export Certificate…**, save a `.p12`
   with a password, and send it privately (AirDrop).
3. The release Mac double-clicks the `.p12` to add it to the login keychain.

If Ovra ever moves to an **Organization** team, the Account Holder can
instead give you the **Admin** role with **Access to Cloud Managed Developer
ID Certificates** (App Store Connect › Users and Access), and Xcode signs
without a `.p12`.

### 3. Notarization credentials
Create an app-specific password at [account.apple.com](https://account.apple.com)
› Sign-In and Security, then store it in the keychain:

```sh
xcrun notarytool store-credentials ovra-notary \
  --apple-id <your Apple ID> --team-id <TEAM_ID>
```

## Making a release

1. Commit everything — the script builds the files on disk.
2. Add the version to `Manager/WhatsNewStore.swift` (shown in the app after the update).
3. Write release notes in a Markdown file.
4. Dry run (builds and signs, uploads nothing):

   ```sh
   OVRA_TEAM_ID=<TEAM_ID> NOTARY_PROFILE=ovra-notary scripts/release.sh 1.0.1 --notes notes.md
   ```

5. Publish:

   ```sh
   OVRA_TEAM_ID=<TEAM_ID> NOTARY_PROFILE=ovra-notary scripts/release.sh 1.0.1 --notes notes.md --publish
   ```

   This creates the GitHub release `v1.0.1`, updates `appcast.xml` and the
   version number, and pushes to `main`. Installed copies see the update within
   a day, or right away with **Check for Updates**.

Build numbers (`CFBundleVersion`) are timestamps, so every release is newer
than the last.
