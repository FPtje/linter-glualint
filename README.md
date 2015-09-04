linter-glua
===========
## Requirements

You will need the following:

* [Atom Linter](https://atom.io/packages/linter).
* [glualint](https://github.com/FPtje/GLuaFixer)

**Note:** This plugin will NOT work if `glualint` is not installed properly! Please follow the installation guide in its README properly!

## Installation

* `$ apm install linter` (if you don't have [Atom Linter](https://atom.io/packages/linter) installed).

* `$ apm install linter-glualint`

## Configuration

Atom -> Preferences... -> Packages -> Linter glualint -> Settings:

* **Executable** Path to your `glualint` executable, if it's not on your system's PATH environment variable.
* **Lint on save** Whether files should be linted only on save or while you type.
