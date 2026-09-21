# Concepts

Shared vocabulary for this repository. Each entry defines what a term means here, not what it means generally.

## Verification

**Repository check** — an automated assertion that runs from the flake and needs nothing but a checkout: it evaluates or builds configuration and fails the build when the result is wrong. Repository checks prove what the configuration *generates*; they can never prove how the installed machine behaves.

**Hardware check** — a manual confirmation performed on the physical laptop after installation, recorded by the person who performed it. Hardware checks cover exactly what a repository check cannot reach: real devices, real firmware, real input. A passing build never substitutes for one, and results from the two are reported separately so neither is mistaken for the other.

**Mutation round** — one deliberate break of something a repository check claims to protect, run to confirm the check turns red, then restored. Rounds are counted per class of assertion rather than per assertion, and a check that has only ever been observed passing has not yet been shown to guard anything.

A round only counts when the check failed *for its own reason*. A break that stops the configuration from evaluating at all, or that trips a different assertion than the one under test, yields a failure that says nothing about the assertion being proven — so what a round establishes is read from where the failure came from, never from the fact that something failed.

A round that stays green is read the same way. The fixture a check runs against is part of what the round tests: when it seeds two sources the code chooses between with the same value, the broken and the correct version compute the same answer, and the round passes without the assertion ever having been able to tell them apart. So a green round is evidence only once the fixture is known to put those sources in states a wrong choice would distinguish.

The same holds when the operand, rather than the fixture, is fixed. An assertion that interpolates a value settled during evaluation — an option another module sets unconditionally — reaches the builder as a comparison of a constant against itself, so no round can turn it red. Whether an assertion is live is therefore a question about what the code under test can change, not about how many rounds have been run against it.

## Signing key

**Card stub** — a keyring entry that records where a private key lives rather than holding it. The key material sits on a hardware token and cannot be read back out, so the entry names the token instead. Signing and decryption still work through it, and a listing distinguishes a stub from a real secret key, which matters because operations that move a key onto a token consume the local copy: once every entry is a stub, there is nothing left to move onto the next token.

**Offline backup** — the passphrase-protected export of the signing key, kept apart from the tokens that carry it. Because a token's private key cannot be extracted, there is no token-to-token path, and every replacement or additional token is provisioned from this backup. Losing it does not lose the key while a token still works, but it does mean the tokens in hand are the last ones that will ever exist.

## FIDO credentials

**Discoverable credential** — a FIDO credential the token stores itself, together with the site it belongs to, so the token can name that site without being told. Its counterpart, a non-discoverable credential, leaves nothing on the token: the site keeps the material and hands it back at sign-in. The distinction sets the ceiling on what any inventory tool here can report — a discoverable credential is listable, a non-discoverable one is unlistable by construction rather than by a gap in the tooling, so a site missing from a listing is not evidence that the credential is absent.

## Hosts

**Bootstrap host** — a second configuration built from the same module set as the production host, with private boot keys and user authentication secrets left out, used to install the machine before those secrets exist. It is not a separate machine or a reduced feature set: anything added to the shared modules reaches it too, so a change must be considered against an installer console as well as a logged-in desktop.
