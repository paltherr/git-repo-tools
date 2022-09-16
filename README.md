# Git Repo Tools

Tools for managing Git repositories.

## Installation

### Homebrew

```sh
brew install paltherr/paltherr/git-repo-tools
```

### Manual

```sh
cd /usr/local/opt
git clone https://github.com/paltherr/git-repo-tools.git
cd /usr/local/bin
ln -s ../opt/git-repo-tools/src/bin/gr-* .
```

## Commands

### Commits

- `gr-head-commit-amend`

    Amends the head commit if it can still be amended on GitHub.

### Latest tag

- `gr-latest-tag`

    Prints the latest tag.

- `gr-latest-tag-update <version>`

    Updates, locally and remotely, the latest tag to refer the
    specified version.

### Release data

- `gr-release-title <version>`

    Prints the release title for the specified version.

- `gr-release-notes <version>`

    Prints the release notes for the specified version. The notes are
    extracted from `CHANGELOG.md`. Notes for a version are expected to
    start with the following line:

    `## [<version>](https://github.com/<owner>/<repo>/releases/tag/v<version>) - <YYYY-MM-DD>`

- `gr-release-tag <version>`

    Prints the release tag for the specified version.

### Release tags

- `gr-release-tag-create <version>`

    Creates, locally and remotely, the release tag for the specified
    version. The tag is annotated with the release notes.

- `gr-release-tag-update <version>`

    Updates, locally and remotely, the tag for the specified version.
    The tag is annotated with the release notes.

- `gr-release-tag-delete <version>`

    Deletes, locally and remotely, the tag for the specified version.

### Releases

- `gr-release-create <version>`

    Creates the release for the specified version.

- `gr-release-update <version>`

    Updates the release for the specified version.

- `gr-release-delete <version>`

    Deletes the release for the specified version.

### Homebrew

- `gr-homebrew-formula-update <version>`

    Updates the homebrew formula source to use the release for the
    specified version. The file `.homebrew-formula` is expected to
    contain the full name of the formula.
