# dotfiles

## Scripts

- **cleanup-dsstore** - Recursively removes .DS_Store files from directories
- **del** - Moves files/folders to trash instead of deleting them

## Setup

Add this to your `.zshrc` to load all scripts:

```bash
# Load all dotfiles scripts
for script in ~/dotfiles/scripts/*.sh; do
    source "$script"
done
```

## Usage

Run any command after installation or use `command -h` for help.
