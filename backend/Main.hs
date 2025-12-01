import Llama
import qualified Data.Text as T
import System.IO
import Control.Monad (forever)

main :: IO ()
main = do
  hSetEncoding stdout utf8
  let serverUrl = "http://localhost:12345"
  forever $ do
    putStr "Enter your question (or 'quit' to exit): "
    hFlush stdout
    question <- getLine
    if question == "quit"
      then return ()
      else do
        let messages = [LlamaMessage User (T.pack question)]
        let req = LlamaApplyTemplateRequest messages
        response <- llamaTemplated serverUrl req
        case response of
          Just text -> putStrLn (T.unpack text)
          Nothing -> putStrLn "Error: No response from server"
        putStrLn ""
