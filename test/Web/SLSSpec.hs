{-# LANGUAGE LambdaCase          #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}
module Web.SLSSpec(main, spec) where
import           Control.Concurrent        (forkIO, killThread)
import           Control.Exception
import           Control.Monad
import           Data.ByteString           (ByteString)
import           Data.ByteString.Char8     (unpack)
import           Data.CaseInsensitive      (CI)
import qualified Data.CaseInsensitive      as CI
import           Data.List                 (isPrefixOf)
import qualified Data.Text.Lazy            as T
import           Network.HTTP
import           Network.HTTP.Types.Header
import           Network.Wai.Test
import           System.Exit               (exitFailure)
import           Test.Hspec
import           Test.Hspec.Wai            as W
import           Test.Hspec.Wai.Internal
import           Web.Scotty                as S
import           Web.Scotty.Cookie         as C
import           Web.Scotty.Login.Session

testPort = 4040
baseURL = "localhost" ++ ":" ++ show testPort

main = do
  hspec spec

spec :: Spec
spec = do
  describe "baseline" $ do
    withApp routes $ do
      it "GET to root returns 200 code" $ do
        W.get "/" `shouldRespondWith` 200

  describe "denial" $ do
    withApp routes $ do
      it "403's if not authed" $ do
        W.get "/authcheck" `shouldRespondWith` 403
      it "denies if not authed" $ do
        W.get "/authcheck" `shouldRespondWith` "denied"

  describe "login" $ do
    withApp routes $ do
      it "logs in successfully" $
        W.postHtmlForm "/login" [("username", "guest"), ("password", "password")] `shouldRespondWith` "authed"

  describe "login session" $ do
    withApp routes $ do
      it "gives sessionID cookie when i log in" $ do
        resp <- W.postHtmlForm "/login" [("username", "guest"), ("password", "password")]
        let hs = simpleHeaders resp
            c  = lookup "Set-Cookie" hs
        -- honestly i am shocked that this works
        liftIO $ c `shouldSatisfy` \case Nothing -> False
                                         Just s -> "SessionId=" `isPrefixOf` unpack s




-- withApp :: ScottyM () -> SpecWith Application -> Spec
withApp = with . scottyApp


----- basic library usage
conf :: SessionConfig
conf = defaultSessionConfig

runScotty :: IO ()
runScotty = do
--  initializeCookieDb conf
  scotty testPort routes

routes :: ScottyM ()
routes = do
  S.get "/" $ S.text "howdy"
  S.get "/login" $ do S.html $ T.pack $ unlines $
                        [ "<form method=\"POST\" action=\"/login\">"
                        , "<input type=\"text\" name=\"username\">"
                        , "<input type=\"password\" name=\"password\">"
                        , "<input type=\"submit\" name=\"login\" value=\"login\">"
                        , "</form>" ]
  S.post "/login" $ do
    (usn :: String) <- param "username"
    (pass :: String) <- param "password"
    if usn == "guest" && pass == "password"
      then do addSession conf
              S.html "authed"
      else do S.html "denied"
  S.get "/authcheck" $ authCheck (S.html "denied") $
    S.html "authorized"
