{ gh, git, writeShellApplication }:
{
  # autorelease <release-assets> <release-notes> [release-tag]
  #
  # release-assets
  #   A path to the directory with release assets, typically something like "$(nix build .#release)"
  # release-notes
  #   Either a path to the file or bare text to use as release notes.
  # release-tag (optional)
  #   A tag for the release to be pushed and also to be used as a release title.
  #   Default value to be used is 'auto-release'.
  #
  # If 'release-tag' is 'autorelease' or 'PRERELEASE' env variable is set to 'true'
  # created release is marked as 'prerelease'.
  #
  # 'OVERWRITE_RELEASE' env variable is set to 'true' an existing release with 'release-tag'
  # will be deleted prior to recreation.
  #
  # This script expects 'GH_TOKEN' env variable to be set to a GitHub PAT that is capable of
  # managing releases in the target repository.
  #
  # Usage examples:
  # autorelease "$(nix build .#release)" "Automatic release on "$(date +\"%Y%m%d%H%M\")""
  #
  # autorelease "$(nix build .#release)" ./release-notes.md "v1.0"
  autorelease = writeShellApplication {
    name = "autorelease";
    runtimeInputs = [ gh git ];
    text = ''
      release_assets="$1"
      release_notes="$2";
      release_tag="''${3:-auto-release}"

      if [[ ''${OVERWRITE_RELEASE:-false} == true ]]; then
        # Delete release if it exists
        gh release delete "$release_tag" --yes || true
        # Delete the tag if it exists to make sure that 'gh release create' uses the latest commit as a tag target
        if git show-ref --tags "$release_tag" --quiet; then
          git tag --delete "$release_tag"
          git push --force --tags
        fi
      fi

      typeset -a release_args
      # Create release
      if [[ $release_tag == "auto-release" || ''${PRERELEASE:-false} == true ]]; then
        release_args+=("--prerelease")
      fi
      if [[ -f $release_notes ]]; then
        release_args+=("--notes-file" "$release_notes")
      else
        release_args+=("--notes" "$release_notes")
      fi
      gh release create "$release_tag" --target "$(git rev-parse HEAD)" --title "$release_tag" "''${release_args[@]}" "$release_assets"/*
    '';
  };
}
