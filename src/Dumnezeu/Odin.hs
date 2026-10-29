module Dumnezeu.Odin (parseProgram, parseExpression) where

import Dumnezeu.Generated.Odin.Abs (Expr, Program)
import Dumnezeu.Generated.Odin.Lex qualified as Lex
import Dumnezeu.Generated.Odin.Par qualified as Par

parseProgram :: FilePath -> String -> Either String Program
parseProgram path source = prefix $ do
  input <- prepare True source
  Par.pProgram input
  where
    prefix = either (Left . ((path ++ ": ") ++)) Right

parseExpression :: String -> Either String Expr
parseExpression source = prepare False source >>= Par.pExpr

prepare :: Bool -> String -> Either String [Lex.Token]
prepare statements source = do
  cleaned <- stripComments source
  let input = Lex.tokens cleaned
  case filter isError input of
    bad : _ -> Left $ "Lexical error at " ++ Lex.tokenPos [bad]
    [] -> case filter ((== "@{") . Lex.tokenText) input of
      bad : _ -> Left $ "Reserved internal token at " ++ Lex.tokenPos [bad]
      [] -> Right $ layout statements input
  where
    isError (Lex.Err _) = True
    isError _ = False

data Frame = Parentheses | Brackets | Body | Literal | Fields deriving (Eq)
data Header = BodyHeader | ProcedureHeader | FieldHeader deriving (Eq)

layout :: Bool -> [Lex.Token] -> [Lex.Token]
layout statements = go [] [] Nothing
  where
    go frames headers previous remaining = case remaining of
      [] -> [semicolon token | statements, inBody frames, Just token <- [previous], endsStatement token]
      token : rest ->
        let text = Lex.tokenText token
            depth = length frames
            gap = maybe False (\old -> endLine old < startLine token) previous
            beforeClose = text == "}" && take 1 frames == [Body]
            insert = statements && inBody frames && maybe False endsStatement previous
              && (gap || beforeClose) && text /= ";"
            prefix = [semicolon token | insert]
            activeHeaders = filter (\(level, kind) -> level <= depth
              && not (level == depth && kind == ProcedureHeader && (insert || text == ";"))) headers
            (output, frames', headers') = case text of
              "(" -> (token, Parentheses : frames, activeHeaders)
              "[" -> (token, Brackets : frames, activeHeaders)
              ")" -> (token, drop 1 frames, activeHeaders)
              "]" -> (token, drop 1 frames, activeHeaders)
              "}" -> (token, drop 1 frames, activeHeaders)
              "{" -> case activeHeaders of
                (level, kind) : more | level == depth ->
                  (token, (if kind == FieldHeader then Fields else Body) : frames, more)
                _ -> (replaceSymbol "@{" token, Literal : frames, activeHeaders)
              "proc" -> header ProcedureHeader
              "if" -> header BodyHeader
              "for" -> header BodyHeader
              "switch" -> header BodyHeader
              "else" -> header BodyHeader
              "struct" -> header FieldHeader
              "enum" -> header FieldHeader
              _ -> (token, frames, activeHeaders)
            header kind = (token, frames, (depth, kind) : filter ((/= depth) . fst) activeHeaders)
        in prefix ++ output : go frames' headers' (Just token) rest

    inBody [] = True
    inBody (frame : _) = frame == Body

startLine :: Lex.Token -> Int
startLine = fst . Lex.tokenLineCol

endLine :: Lex.Token -> Int
endLine token = startLine token + length (filter (== '\n') (Lex.tokenText token))

endsStatement :: Lex.Token -> Bool
endsStatement token = case token of
  Lex.PT _ (Lex.TV _) -> True
  Lex.PT _ (Lex.TL _) -> True
  Lex.PT _ (Lex.TD _) -> True
  Lex.PT _ (Lex.TC _) -> True
  Lex.PT _ (Lex.T_IntegerLiteral _) -> True
  Lex.PT _ (Lex.T_FileTag _) -> True
  _ -> Lex.tokenText token `elem` [")", "]", "}", "^", "---", "_", "context", "true", "false", "nil", "return", "break", "continue"]

semicolon :: Lex.Token -> Lex.Token
semicolon = replaceSymbol ";"

replaceSymbol :: String -> Lex.Token -> Lex.Token
replaceSymbol text token = case Lex.tokens text of
  [Lex.PT _ symbol] -> Lex.PT (Lex.tokenPosn token) symbol
  _ -> error $ "Missing generated lexer symbol: " ++ text

stripComments :: String -> Either String String
stripComments = scan
  where
    scan [] = Right []
    scan ('/' : '/' : rest) =
      let (line, more) = break (== '\n') rest
      in (("//" ++ line) ++) <$> scan more
    scan ('/' : '*' : rest) = ("  " ++) <$> block (1 :: Int) rest
    scan ('"' : rest) = ('"' :) <$> quoted '"' rest
    scan ('\'' : rest) = ('\'' :) <$> quoted '\'' rest
    scan (c : rest) = (c :) <$> scan rest

    quoted _ [] = Left "Unterminated quoted literal"
    quoted quote ('\\' : c : rest) = ('\\' :) . (c :) <$> quoted quote rest
    quoted quote (c : rest)
      | c == quote = (c :) <$> scan rest
      | otherwise = (c :) <$> quoted quote rest

    block _ [] = Left "Unterminated block comment"
    block depth ('/' : '*' : rest) = ("  " ++) <$> block (depth + 1) rest
    block depth ('*' : '/' : rest)
      | depth == 1 = ("  " ++) <$> scan rest
      | otherwise = ("  " ++) <$> block (depth - 1) rest
    block depth (c : rest) = ((if c == '\n' then '\n' else ' ') :) <$> block depth rest
