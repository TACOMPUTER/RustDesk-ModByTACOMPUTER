# TACOMPUTER RustDesk 1.5.3 Mod - source package status

This source package adds a first-pass **Local Address Book** tab immediately after **Discovered** and before the original **Address book** tab.

## Implemented in this source snapshot
- New Local Address Book tab (independent of the RustDesk Pro Address Book).
- Add, edit, delete entries with display name and RustDesk ID / IP / hostname.
- Search entries by name/address.
- Scrollable device list and per-entry Connect action.
- Local JSON data file named `Address_Book.txt`.
- Hostname resolution through the operating system resolver before Direct IP connection.
- Saved entries are stored in the portable executable directory when writable; otherwise in the user's application-support directory.

## Not yet implemented / must not be treated as production-ready
- Passwords are accepted for the current app session and passed to RustDesk's normal connect flow, but are **not persisted**. This is intentional: the source does not yet contain portable authenticated encryption and a safe cross-machine import/key workflow. Do not store passwords in plaintext or treat base64/obfuscation as encryption.
- Import / Export UI is not implemented in this first-pass snapshot.
- No Windows or Linux compilation has been run in this environment. Build and runtime testing are still required.
- Hostname connection depends on DNS / hosts-file / VPN name resolution being available from the client machine. The resolved address is passed to RustDesk Direct IP connection; the remote host must allow Direct IP access and the required port must be reachable.

## Tab order
Recent sessions -> Favorites -> Discovered -> Local Address Book -> Address book -> Accessible devices.

## Test focus
1. Build Windows and Linux desktop targets.
2. Open Local Address Book and add a numeric ID, an IP, and a hostname such as `A02HP-ABCXYZ`.
3. Restart and verify entries persist.
4. Test hostname resolution from the same LAN and over VPN.
5. Verify an entry without a saved password uses RustDesk's normal password prompt.
6. Report compiler errors with the complete first error and surrounding output before further changes.
