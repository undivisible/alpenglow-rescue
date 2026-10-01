# Alpenglow Rescue

A separate rescue-image project based on pinned Alpenglow, inspired by
[Omarchy Rescue](https://github.com/crmne/omarchy-rescue).

Development goals: a complete compressed bootable artifact under 500,000,000
bytes and interactive rescue readiness in one-quarter the baseline time. These
are **targets, not achieved measurements**. Broad drivers, firmware and essential
rescue tools stay in the candidate, even if the image misses the size target.

See [feature and license matrix](docs/feature-license-matrix.md) for scope and
known gaps. Build/test recipes and benchmark evidence are being developed.
No authentication, host-disk repair, USB flashing, binary release, or social
announcement is part of this development run.

The Alpenglow submodule is pinned to `2214bc159355522bbebc61e8e90ca78933a8e1ac`.
Alpenglow-derived sources and this project use MPL-2.0. Image components retain
their own licenses; Omarchy Rescue's MIT attribution is in `licenses/`.
