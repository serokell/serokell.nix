# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

###
# Working with sources
###

{ lib, gitignore-nix }:

{
  # Clean the source to leave only files tracked by git.
  #
  # name: name of the directory.
  #       Yes it is boring to always specify the name explicitly,
  #       but this way we guarantee no unexpected issues with caching.
  # src: directory to clean. This is typically `./.`.
  cleanGit = name: src:
    gitignore-nix.gitignoreSource (lib.cleanSourceWith {
      inherit name;
      src = builtins.unsafeDiscardStringContext src;
    });

  # Restrict the source to only a subdirectory.
  #
  # subDir: name of the subdirectory.
  # src: original source.
  #
  # This function composes well with `cleanGit` above and the expected
  # usage pattern is:
  #
  # ```
  # src = subdir "backend" (cleanGit "project" ./.);
  # ```
  #
  # or
  #
  # ```
  # let
  #   topLevel = cleanGit "project" ./.;
  #   backendSrc = subdir "backend" topLevel;
  #   fronendSrc = subdir "frontend" topLevel;
  # in ...
  # ```
  subdir = subDir: src:
    # Doesn't actually clean anything but composes well with `cleanGit`.
    lib.cleanSourceWith {
      inherit src;
      inherit subDir;
    };
}
