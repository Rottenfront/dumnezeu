module Main (main) where

import Control.Monad (unless)
import Data.Either (isLeft)
import Data.List (isSuffixOf, sort)
import Dumnezeu.Generated.Odin.Abs
import Dumnezeu.Odin (parseExpression, parseProgram)
import System.Directory (listDirectory)
import System.Exit (exitFailure)
import System.FilePath ((</>))

main :: IO ()
main = do
  files <- sort . filter (isSuffixOf ".odin") <$> listDirectory "tests/odin"
  fixtures <- mapM checkFixture files
  checks <- sequence
    [ check "multiplication precedence" $
        parseExpression "2 + 3 * 4" == Right (EAdd (number "2") (EMul (number "3") (number "4")))
    , check "left associativity" $
        parseExpression "10 - 3 - 2" == Right (ESub (ESub (number "10") (number "3")) (number "2"))
    , check "parenthesized expression" $
        parseExpression "(2 + 3) * 4" == Right (EMul (EAdd (number "2") (number "3")) (number "4"))
    , check "postfix dereference and field" $
        parseExpression "node.next^.value" == Right (EField (EDeref (EField (EName (Ident "node")) (Ident "next"))) (Ident "value"))
    , accepted "one-line body and EOF semicolon" "package main; main :: proc() { x := 1 }"
    , accepted "nested comments" "package main\n/* outer /* inner */ end */\nmain :: proc() {}"
    , accepted "comment delimiters inside strings" "package main; main :: proc() { x := \"/* not a comment */\" }"
    , accepted "multiline call" "package main\nmain :: proc() {\nf(\n1,\n2,\n)\n}"
    , accepted "parenthesized compound literal in header" "package main; main :: proc() { if (Point{x = 1}).x > 0 { return } }"
    , accepted "compound literal as call argument" "package main; main :: proc() { f(Point{x = 1}) }"
    , accepted "newline after pointer dereference" "package main\nmain :: proc() {\nx := p^\nx += 1\n}"
    , accepted "procedure type before compound literal" "package main\nmain :: proc() {\nf: proc(int, int) -> int\nx := Point{1, 2}\n}"
    , accepted "context expression newline" "package main\nmain :: proc() {\nx := context\nf(x)\n}"
    , accepted "dynamic array allocation" "package main; main :: proc() { x := make([dynamic]int, 0, 16) }"
    , rejected "missing package" "main :: proc() {}"
    , rejected "missing initializer" "package main; main :: proc() { x := }"
    , rejected "missing closing brace" "package main; main :: proc() { x := 1"
    , rejected "missing operand" "package main; main :: proc() { x := 1 + }"
    , rejected "missing argument separator" "package main; main :: proc() { f(1 2) }"
    , rejected "invalid character" "package main; main :: proc() { x := `raw` }"
    , rejected "unterminated comment" "package main; /* not closed"
    , rejected "unterminated string" "package main; main :: proc() { x := \"not closed"
    , rejected "internal marker is not source syntax" "package main; main :: proc() { x := Point@{} }"
    , check "expression parser rejects trailing garbage" $ isLeft (parseExpression "1 2")
    ]
  unless (and (fixtures ++ checks)) exitFailure
  putStrLn $ "All " ++ show (length fixtures + length checks) ++ " parser checks passed"

number :: String -> Expr
number = EInteger . IntegerLiteral

checkFixture :: FilePath -> IO Bool
checkFixture file = do
  let path = "tests/odin" </> file
  source <- readFile path
  case parseProgram path source of
    Left message -> putStrLn ("FAIL " ++ file ++ ": " ++ message) >> pure False
    Right _ -> check ("parse fixture " ++ file) True

accepted :: String -> String -> IO Bool
accepted label source = case parseProgram "<test>" source of
  Left message -> putStrLn ("FAIL " ++ label ++ ": " ++ message) >> pure False
  Right _ -> check label True

rejected :: String -> String -> IO Bool
rejected label = check label . isLeft . parseProgram "<test>"

check :: String -> Bool -> IO Bool
check label ok = putStrLn ((if ok then "PASS " else "FAIL ") ++ label) >> pure ok
