{ pkgs }:

let
  haskell = pkgs.haskell.packages.ghc9103;
in
pkgs.mkShell {
  packages = [
    (haskell.ghcWithPackages (ps: [ ps.parsec ]))
    haskell.haskell-language-server
    haskell.implicit-hie
    pkgs.fourmolu
    pkgs.cabal-install
    pkgs.odin
    haskell.BNFC
    haskell.alex
    haskell.happy
  ];
}
