# Clipboard

| Key | Operation |
|---|---|
| `yf` | Copy selected files to the macOS clipboard; paste with Cmd-V in a supporting browser/app |
| `ya` | Copy absolute paths as text |
| `yr` | Copy paths relative to the current Yazi directory |
| `yn` | Copy filenames |
| `yy` | Yank for copying inside Yazi |
| `yi` | Legacy alias for copying image files as files (same clipboard format as `yf`) |

Select multiple files with Space, or press v and move with j/k to select a range.
The clipboard keys finalize the visual range automatically; without a selection, the hovered file is used.
Text lists are separated by newlines. Copying shows a success notification with the copied
names/paths, or an error notification. File copying uses macOS file URLs rather than path text,
without opening Finder or asking Finder to control the clipboard. Browser upload support for
Cmd-V depends on the website. Restart an already open Yazi to load the new keymap.

# Navigation and opening

| Key | Operation |
|---|---|
| `gr` | Go to the current Git root; show an error outside a repository |
| `gp` | Select a project or worktree from the shared workspace cache |
| `ov` | Open selected files in the terminal editor, in the foreground |
| `oc` | Open selected files in VSCode without blocking Yazi |
| `of` / `ob` | Reveal selected files in Finder / open in the configured browser |
| `ok` | Open Ghostty in the hovered directory, or the hovered file's parent |
| `ott` | Create a window in the current tmux session |
| `otc` / `ots` | Pick a tmux session to create a window in / switch to |
| `otn` | Create a tmux session; switch to it if already inside tmux |

Terminal directory commands use the hovered item, rather than combining multiple paths.
Session and project pickers do nothing when cancelled. `ott` and `ots` require an existing
tmux client; they show an error when used from a standalone terminal or TUIOS.
`yi` copies a file reference, not image pixels. It and `yf` no longer require Finder automation.

# Archive operations

| Key | Operation |
|---|---|
| `zz` | Enter a name and create a ZIP archive |
| `zg`, `za` | Enter a name and create a tar.gz archive |
| `zt` | Enter a name and create a tar archive |
| `zx` | Extract selected archives into the current directory |
| `zX` | Extract each archive into its own directory |

Select files with Space; without a selection, the hovered file is used.
Operations use atool with the installed tar/zip/unzip/7zz tools. Sevenzip's `7zz` is explicitly selected for 7z archives.
Commands run in the foreground so progress, errors, password requests, and overwrite prompts are visible.
Compression asks for an output filename. Enter accepts the suggested name (selected file/folder name, or `archive` for multiple selections); Ctrl-d cancels. The selected archive extension is added automatically.
After success, the resulting filename and full path stay visible until Enter. Yazi then reveals the new archive. Extraction also keeps its output visible until Enter.
On failure, press Enter to return to Yazi. Existing output archives are left untouched; choose another name or rename them before compressing again.
Multiple selections and names containing spaces are passed as separate arguments. Archive members under the current directory use relative paths.
