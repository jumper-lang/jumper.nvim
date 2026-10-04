# jumper.nvim

Support for [Jumper](https://github.com/jumper-lang/jumper) in Neovim: scripts (`.jmp`), configs (`.jmc`) and access policies (`.jma`).

Highlighting, diagnostics, hover, completion, go to definition (into Java too), references, rename and more - through the Jumper language server.

Requires Neovim 0.9+, **Java 21+** and `curl`.

## Install (lazy.nvim / LazyVim)

```lua
{ "jumper-lang/jumper.nvim", lazy = false, opts = {} }
```

The first Jumper file you open downloads the language server (`jmp.jar`) from [jumper Releases](https://github.com/jumper-lang/jumper/releases), checks its SHA-256 and keeps it in Neovim's data folder. `:JumperInstall` downloads it again.

## Install without a plugin manager

```
git clone https://github.com/jumper-lang/jumper.nvim ~/.local/share/nvim/site/pack/jumper/start/jumper.nvim
```

On Windows the folder is `%LOCALAPPDATA%\nvim-data\site\pack\jumper\start\jumper.nvim`. Then in `init.lua`:

```lua
require("jumper").setup()
```

## Use a jmp.jar from GitHub Releases

To run a server you downloaded yourself (from [jumper Releases](https://github.com/jumper-lang/jumper/releases)), point the plugin at it:

```lua
{ "jumper-lang/jumper.nvim", lazy = false, opts = { jar = "C:/tools/jmp.jar" } }
```

## Options

| Option | Default | What |
|---|---|---|
| `java` | `JAVA_HOME`, then `java` | The `java` to run the server with |
| `jar` | downloaded release | Your own `jmp.jar` |
| `jvm_args` | `{}` | Extra JVM arguments, e.g. `{ "-Xmx512m" }` |
