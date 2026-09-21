# Concepts

Shared vocabulary for this repository. Each entry defines what a term means here, not what it means generally.

## Verification

**Repository check** — an automated assertion that runs from the flake and needs nothing but a checkout: it evaluates or builds configuration and fails the build when the result is wrong. Repository checks prove what the configuration *generates*; they can never prove how the installed machine behaves.

**Hardware check** — a manual confirmation performed on the physical laptop after installation, recorded by the person who performed it. Hardware checks cover exactly what a repository check cannot reach: real devices, real firmware, real input. A passing build never substitutes for one, and results from the two are reported separately so neither is mistaken for the other.

## Hosts

**Bootstrap host** — a second configuration built from the same module set as the production host, with private boot keys and user authentication secrets left out, used to install the machine before those secrets exist. It is not a separate machine or a reduced feature set: anything added to the shared modules reaches it too, so a change must be considered against an installer console as well as a logged-in desktop.
