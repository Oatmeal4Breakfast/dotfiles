# macOS dotfiles

Personal configuration for a Mac Studio and MacBook Pro, managed with
[GNU Stow](https://www.gnu.org/software/stow/). Both machines use the same
Brewfile, Stow packages, and LaunchAgents. Machine-specific home paths are
rendered when the agents are installed.

## Fresh installation

```bash
curl -fsSL https://raw.githubusercontent.com/Oatmeal4Breakfast/dotfiles/main/install_script.sh | bash
```

The installer:

1. Checks for the Xcode Command Line Tools.
2. Installs Homebrew when needed.
3. Clones or safely updates `~/dotfiles`.
4. Installs the shared `Brewfile` and OpenCode.
5. Restows every configuration package.
6. Renders and loads the `brew-update` and `wallsync` LaunchAgents.

The installer is repeatable and non-destructive. It does not remove or back up
configuration that blocks Stow.

## Migrating an existing Mac

Preview known legacy links and conflicting configuration:

```bash
~/dotfiles/migrate-to-stow.sh
```

Apply the reported migration:

```bash
~/dotfiles/migrate-to-stow.sh --apply
~/dotfiles/install_script.sh
```

The migration script only handles paths owned by this repository. It:

- removes legacy absolute or dangling links that point into this checkout;
- leaves valid Stow links alone unless a package root must be unfolded;
- moves conflicting real files or directories to timestamped backups;
- moves OpenCode runtime artifacts out of older folded packages; and
- verifies the result with a Stow simulation.

Nothing changes without `--apply`.

## Packages

Every package mirrors its path below `$HOME`:

```text
aerospace/.aerospace.toml
ghostty/.config/ghostty/
git/.gitconfig
lazygit/.config/lazygit/
nvim/.config/nvim/
opencode/.config/opencode/
rex/.config/rex/
starship/.config/starship.toml
tmux/.tmux.conf
zsh/.zshrc
```

Most packages may be folded into a single directory symlink. OpenCode and Rex
are always installed with `--no-folding`, leaving `~/.config/opencode` and
`~/.config/rex` as real directories. This prevents application-generated
runtime files, dependencies, state, and secrets from being written into the
Git checkout.

## Manual Stow usage

Restow the normal packages:

```bash
cd ~/dotfiles
stow --restow --target="$HOME" \
  aerospace ghostty git lazygit nvim starship tmux zsh
```

Restow the packages that must remain unfolded:

```bash
cd ~/dotfiles
stow --restow --no-folding --target="$HOME" opencode rex
```

Remove one package:

```bash
cd ~/dotfiles
stow --delete --target="$HOME" PACKAGE
```

## LaunchAgents

The installer renders both templates directly into `~/Library/LaunchAgents`:

- `com.$USER.brew-update.plist`
- `com.$USER.wallsync.plist`

`__HOME__`, `__USER__`, and `__DOTFILES_DIR__` placeholders are expanded for
the current machine. Generated plists do not live in this repository.

The maintenance agent updates Homebrew daily and refreshes the Brewfile when
installed packages change. The wallpaper agent synchronizes the configured
wallpaper directory daily. Logs are written beneath `~/Library/Logs`.
