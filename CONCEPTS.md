# Concepts

Shared vocabulary for this repository. Each entry defines what a term means here, not what it means generally.

## Verification

**Repository check** — an automated assertion that runs from the flake and needs nothing but a checkout: it evaluates or builds configuration and fails the build when the result is wrong. Repository checks prove what the configuration *generates*; they can never prove how the installed machine behaves.

**Hardware check** — a manual confirmation performed on the physical laptop after installation, recorded by the person who performed it. Hardware checks cover exactly what a repository check cannot reach: real devices, real firmware, real input. A passing build never substitutes for one, and results from the two are reported separately so neither is mistaken for the other.

**Mutation round** — one deliberate break of something a repository check claims to protect, run to confirm the check turns red, then restored. Rounds are counted per class of assertion rather than per assertion, and a check that has only ever been observed passing has not yet been shown to guard anything.

A round only counts when the check failed *for its own reason*. A break that stops the configuration from evaluating at all, or that trips a different assertion than the one under test, yields a failure that says nothing about the assertion being proven — so what a round establishes is read from where the failure came from, never from the fact that something failed.

A round that stays green is read the same way. The fixture a check runs against is part of what the round tests: when it seeds two sources the code chooses between with the same value, the broken and the correct version compute the same answer, and the round passes without the assertion ever having been able to tell them apart. So a green round is evidence only once the fixture is known to put those sources in states a wrong choice would distinguish.

## Hosts

**Bootstrap host** — a second configuration built from the same module set as the production host, with private boot keys and user authentication secrets left out, used to install the machine before those secrets exist. It is not a separate machine or a reduced feature set: anything added to the shared modules reaches it too, so a change must be considered against an installer console as well as a logged-in desktop.
