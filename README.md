<!--
SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>

SPDX-License-Identifier: MPL-2.0
-->

# serokell.nix

Serokell Nix infrastructure library


## Nixpkgs resolution

The Serokell flake registry resolves the `nixpkgs` name to upstream Nixpkgs.
Each infrastructure flake selects its own Nixpkgs revision and records it in
`flake.lock`. Consumers using this library with that package set can set
`serokell-nix.inputs.nixpkgs.follows = "nixpkgs"`.

## License

[MPL-2.0] © [Serokell]

[MPL-2.0]: https://spdx.org/licenses/MPL-2.0.html
[Serokell]: https://serokell.io/
