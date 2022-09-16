# Releasing a new version

To create a release for a new version (of this repository or another
one):

- Define a new version number `<version>` using the syntax
  `<major>.<minor>.<patch>`.

- Move the content of the unreleased entry to a new `<version>` entry
  at the top of `CHANGELOG.md`.

- Commit the changes with the message `Version <version>`.

- In a shell, set `VERSION` to `<version>` and run the following
  commands:

  ```sh
  gr-release-tag-create $VERSION
  gr-latest-tag-update $VERSION
  gr-release-create $VERSION
  gr-homebrew-formula-update $VERSION
  ```
