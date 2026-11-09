module Main (main) where

import Dumnezeu.Odin (parseProgram)
import System.Environment (getArgs)
import System.Exit (die)
import Text.Pretty.Simple (pPrint)

main :: IO ()
main = do
    args <- getArgs
    case args of
        [] -> putStrLn "Hello, Haskell!"
        [path] -> do
            source <- readFile path
            case parseProgram path source of
                Left message -> die message
                Right ast -> pPrint ast
        _ -> die "Usage: dumnezeu [source.odin]"
