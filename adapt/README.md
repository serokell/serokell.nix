<!--
SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>

SPDX-License-Identifier: MPL-2.0
-->

Some of the repositories we depend on are structured in various _original_
ways and it is impossible to just import them and use directly, for example,
for their library. But we really want their library functions.

Hence, we adapt them to a more sane flake-like structure.
