import Control.Exception (evaluate)
import Control.Monad (when)
import Data.List (isInfixOf)
import Distribution.Simple
import System.Directory (createDirectoryIfMissing, doesFileExist, findExecutable)
import System.FilePath ((</>))
import System.Process (callProcess, readProcess)

main :: IO ()
main = defaultMainWithHooks simpleUserHooks
  { preConf = \args flags -> generate >> preConf simpleUserHooks args flags
  , preBuild = \args flags -> generate >> preBuild simpleUserHooks args flags
  , preRepl = \args flags -> generate >> preRepl simpleUserHooks args flags
  }

generate :: IO ()
generate = do
  tools <- mapM requireTool ["bnfc", "alex", "happy"]
  versions <- mapM (\tool -> readProcess tool ["--version"] "") tools
  grammar <- readStrict "grammar/Odin.cf"
  setup <- readStrict "Setup.hs"
  let signature = unlines versions ++ setup ++ grammar
      stamp = "generated" </> ".grammar-stamp"
      directory = "generated" </> "Dumnezeu" </> "Generated" </> "Odin"
      outputs = map (directory </>) ["Abs.hs", "Lex.hs", "Par.hs", "Print.hs", "Lex.x", "Par.y", "Par.info"]
  oldSignature <- doesFileExist stamp >>= \exists -> if exists then readStrict stamp else pure ""
  complete <- and <$> mapM doesFileExist outputs
  when (oldSignature /= signature || not complete) $ do
    putStrLn "Generating Haskell from grammar/Odin.cf (BNFC -> Alex/Happy)"
    createDirectoryIfMissing True "generated"
    case tools of
      [bnfc, alex, happy] -> do
        callProcess bnfc ["--haskell", "-d", "-p", "Dumnezeu.Generated", "-o", "generated", "grammar/Odin.cf"]
        callProcess alex [directory </> "Lex.x"]
        callProcess happy ["-gca", "-i", directory </> "Par.y"]
      _ -> fail "Unexpected generator tool configuration"
    report <- readStrict (directory </> "Par.info")
    when ("conflicts." `isInfixOf` report) $
      fail "Grammar conflicts found: resolve them using generated/Dumnezeu/Generated/Odin/Par.info"
    writeFile stamp signature

requireTool :: String -> IO FilePath
requireTool name = do
  result <- findExecutable name
  case result of
    Just path -> pure path
    Nothing -> fail $ "Missing parser generator: " ++ name ++ ". Run this command inside nix-shell."

readStrict :: FilePath -> IO String
readStrict path = do
  contents <- readFile path
  _ <- evaluate (length contents)
  pure contents
