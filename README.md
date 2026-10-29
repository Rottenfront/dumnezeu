# Dumnezeu

An Odin-subset compiler project written in Haskell.

## Development environment

`flake.lock` pins nixpkgs. The default development shell is available for `x86_64-linux` and `aarch64-linux`; the package list lives in `nix/dev-shell.nix` and is shared by both entry points:

```sh
nix develop
# Or the classic interface, using the same locked nixpkgs:
nix-shell
```

Git-backed flakes only include tracked files. Before these new Nix files are staged, use `nix develop path:.` (or `nix-shell`). After adding `flake.nix`, `flake.lock` and `nix/dev-shell.nix` to Git, plain `nix develop` works. The `path:.` form includes the working directory rather than filtering it through Git, so large build directories can make it slower.

Run commands without entering an interactive shell:

```sh
nix develop -c cabal build
nix develop -c cabal test --test-show-details=direct
nix develop -c cabal run dumnezeu -- tests/odin/05_fibonacci_recursive.odin
# Before staging, use: nix develop path:. -c cabal build

nix-shell --run 'cabal build'
nix-shell --run 'cabal test --test-show-details=direct'
```

If flakes are not enabled in your Nix configuration, use the per-command flags rather than changing system configuration:

```sh
nix --extra-experimental-features 'nix-command flakes' develop path:.
```

The complete explicit package list is:

- `haskell.packages.ghc9103.ghcWithPackages (ps: [ ps.parsec ])`
- `haskell.packages.ghc9103.haskell-language-server`
- `haskell.packages.ghc9103.implicit-hie` (provides `gen-hie`)
- `fourmolu`
- `cabal-install`
- `odin`
- `haskell.packages.ghc9103.BNFC`
- `haskell.packages.ghc9103.alex`
- `haskell.packages.ghc9103.happy`

GHC and Haskell Language Server come from the same compiler package set. The GHC wrapper exposes Parsec for ad-hoc GHC/GHCi use; Cabal components must still declare `parsec` themselves when importing it. The existing `hie.yaml` is retained; `gen-hie` is available but is not run automatically.

To deliberately upgrade the pinned environment, run `nix flake update nixpkgs`, then review and commit the updated `flake.lock`. Use `nix flake update --flake path:. nixpkgs` before staging the flake. Changing your global Nix channel does not change this shell. `shell.nix` also accepts an explicit `pkgs` argument for intentional overrides; the default remains pinned.

## Generated parser

`grammar/Odin.cf` is the generator-ready source of truth. It uses BNFC's labelled BNF (LBNF), **not** the reference EBNF notation. Edit the `.cf` file, not the generated Haskell. `resources/odin.ebnf` is an unchanged upstream reference; no automatic EBNF-to-LBNF conversion is claimed.

Cabal's custom `Setup.hs` invokes BNFC, Alex and Happy during configuration/build/repl. Outputs go under the ignored `generated/Dumnezeu/Generated/Odin/` directory:

- `Abs.hs`: Haskell syntax-tree types.
- `Lex.x` -> `Lex.hs`: Alex lexer.
- `Par.y` -> `Par.hs`: Happy parser.
- `Print.hs`: BNFC pretty printer.
- `Par.info`: parser-state report for investigating grammar conflicts.

Generation is cached using the grammar contents, `Setup.hs` contents and generator versions. Cabal tracks `grammar/Odin.cf`, so editing it triggers regeneration on the next build. Generation fails if Happy reports grammar conflicts. Missing generators produce an error directing you to `nix-shell`.

Cabal may skip hooks entirely for an up-to-date build. If you manually delete generated outputs, run `nix-shell --run 'cabal clean && cabal build'` to force a fresh build. Generated modules are marked as `autogen-modules`; a source distribution includes the grammar and generators' configuration, not generated Haskell snapshots.

Versions verified here: GHC 9.10.3, cabal-install 3.16.1.0, BNFC 2.9.6.3, Alex 3.5.4.2 and Happy 2.1.7. The runtime Haskell packages are `base` and `array`; custom setup uses `base`, `Cabal`, `directory`, `filepath` and `process`, all available with the selected GHC toolchain. Tests additionally use `directory` and `filepath`. Nix also fetched the BNFC support dependency `string-qq` 0.0.6 and the tools' documentation/data outputs.

The library exposes `Dumnezeu.Odin.parseProgram`, `parseExpression`, and the generated AST module `Dumnezeu.Generated.Odin.Abs`. The executable prints an AST for a supplied source file. It does not execute Odin programs or type-check them.

The generated front end is separate from any handwritten parser work; the build only compiles the modules listed in `dumnezeu.cabal`.

## Subset and handwritten lexer adapter

The grammar covers packages/imports, declarations, procedures/calls, structs/enums, arithmetic and logical operators, assignments, conditionals, loops, returns, arrays/slices, dynamic arrays, and pointers. It is an evolving Odin **subset**, not a complete implementation of the upstream grammar.

`src/Dumnezeu/Odin.hs` handles nested block comments, automatic semicolon insertion and the distinction between body braces and compound-literal braces. The internal token `@{` in the LBNF is synthesized by that adapter; users write ordinary `{`. It is not valid source syntax. BNFC's raw pretty printer emits that internal marker, so it is not yet an Odin source formatter.

Compound literals in control-flow headers must be parenthesized. Struct fields and enum entries currently require trailing commas. Anonymous procedure-type parameters are supported, but named parameters in procedure types, maps, polymorphism, attributes, most directives, raw strings, Unicode identifiers and full numeric-literal syntax are not implemented. Standalone blocks, general labels and some control-flow variants are also outside the initial subset.

Declaration and range-binding targets are represented as expression lists in the generated AST. Checking that they are identifiers/valid bindings, checking assignability, resolving names and checking types remain the semantic checker's responsibility. The `invalid_*.odin` fixtures intentionally parse successfully: their errors are semantic, not syntactic.

`tests/odin/` contains the reference Odin fixtures. `tests/haskell/` contains regression checks for the generated parser, including AST precedence checks and malformed syntax. The original fixtures are not changed by code generation.
