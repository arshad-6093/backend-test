{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeOperators #-}

module Main where

-- Base Haskell libraries
import Control.Concurrent (forkIO, threadDelay)
import Control.Concurrent.STM
import Control.Exception (try)
import Control.Monad (forever)
import Control.Monad.IO.Class (liftIO)
import Data.Aeson (FromJSON, ToJSON)
import Data.Bifunctor (second)
import Data.Maybe (fromMaybe)
import Data.Time.Clock
import GHC.Generics

-- Strict Map operations
import qualified Data.Map.Strict as Map

-- ByteString manipulation
import qualified Data.ByteString.Lazy.Char8 as BSL

-- HTTP client and server
import Network.HTTP.Client (HttpException, responseTimeoutMicro, responseTimeout)
import Network.HTTP.Simple (httpJSONEither, parseRequest, setRequestQueryString, getResponseBody)
import Network.Wai.Handler.Warp (run)

-- Servant framework
import Servant

-- Environment variables
import System.Environment (lookupEnv)


-- Defining the API
type API =
  "categories" :> "like"
    :> QueryParam "name" String
    :> QueryParam "levels" String
    :> Get '[JSON] Categories

-- Data Types
data Categories = Categories
  { categories :: [Category],
    grants :: Maybe [String] -- Null field in the json, not sure about the type.
  }
  deriving (Eq, Show, Generic, ToJSON, FromJSON)

data Category = Category
  { id :: Int,
    level :: Int,
    name :: String,
    parent :: Maybe Category,
    path :: String,
    slug :: String,
    translations :: Translation
  }
  deriving (Eq, Show, Generic, ToJSON, FromJSON)

data Translation = Translation
  { ca :: String,
    de :: String,
    el :: String,
    en :: String,
    es :: String,
    fr :: String,
    it :: String,
    nl :: String,
    pt :: String,
    zh :: String
  }
  deriving (Eq, Show, Generic, ToJSON, FromJSON)

type Cache = Map.Map String (Categories, UTCTime)

-- Initialize the cache
initializeCache :: IO (TVar Cache)
initializeCache = newTVarIO Map.empty

-- Fetch categories from external API
fetchCategories :: Maybe String -> Maybe String -> IO (Either String Categories)
fetchCategories mName mLevel = do
  let baseURL = "https://dev.centralapp.com/api/v2/static/categories/like"
  let queryParams =
        [ ("name", mName),
          ("levels", mLevel),
          ("language", Just "en")
        ]
  request <-
    setRequestQueryString (map (second (fmap (BSL.toStrict . BSL.pack))) queryParams)
      <$> parseRequest baseURL
  let requestWithTimeout = request { responseTimeout = responseTimeoutMicro 5000000 } -- 5 seconds
  result <- try $ httpJSONEither requestWithTimeout
  case result of
    Left (ex :: HttpException) -> return $ Left $ "HTTP request failed: " ++ show ex
    Right response ->
      case getResponseBody response of
        Left _ -> return $ Left "Failed to parse JSON from API response."
        Right categories' -> return $ Right categories'

-- Cache Operations
lookupCache :: TVar Cache -> String -> IO (Maybe Categories)
lookupCache cacheTVar key = do
  ttlSeconds <- getTTL
  cache <- readTVarIO cacheTVar
  case Map.lookup key cache of
    Just (categories', timestamp) -> do
      currentTime <- getCurrentTime
      if diffUTCTime currentTime timestamp < ttlSeconds
        then do
          putStrLn $ "Cache hit for key: " ++ key
          return (Just categories')
        else do
          putStrLn $ "Cache expired for key: " ++ key
          return Nothing
    Nothing -> do
      putStrLn $ "Cache miss for key: " ++ key
      return Nothing

updateCache :: TVar Cache -> String -> Categories -> IO ()
updateCache cacheTVar key value = do
  currentTime <- getCurrentTime
  putStrLn $ "Updating cache for key: " ++ key
  atomically $ modifyTVar' cacheTVar $ Map.insert key (value, currentTime)

-- Cleanup expired cache entries
cleanupCache :: TVar Cache -> IO ()
cleanupCache cacheTVar = forever $ do
  ttlSeconds <- getTTL
  interval <- getCleanupInterval
  cache <- readTVarIO cacheTVar
  let originalSize = Map.size cache
  currentTime <- getCurrentTime
  atomically $ modifyTVar' cacheTVar $ Map.filter (\(_, ts) -> diffUTCTime currentTime ts < ttlSeconds)
  cache' <- readTVarIO cacheTVar
  let newSize = Map.size cache'
  putStrLn $ "Cache cleanup: size reduced from " ++ show originalSize ++ " to " ++ show newSize
  threadDelay (interval * 1000000)

-- Server Handler
serverHandler :: TVar Cache -> Maybe String -> Maybe String -> Handler Categories
serverHandler cacheTVar mName mLevel = do
  let key = fromMaybe "" mName ++ "|" ++ fromMaybe "" mLevel
  cached <- liftIO $ lookupCache cacheTVar key
  case cached of
    Just categories' -> return categories'
    Nothing -> do
      result <- liftIO $ fetchCategories mName mLevel
      case result of
        Left err -> throwError $ err500 {errBody = BSL.pack err}
        Right categories' -> do
          liftIO $ updateCache cacheTVar key categories'
          return categories'

-- Load TTL, Port and cleanup interval from Environment Variables
getTTL :: IO NominalDiffTime
getTTL = do
  ttlStr <- lookupEnv "TTL_SECONDS"
  case ttlStr of
    Just s | all (`elem` ['0' .. '9']) s -> return $ fromInteger (read s)
    _ -> do
      putStrLn "Invalid TTL_SECONDS; defaulting to 60 seconds."
      return 60

getPort :: IO Int
getPort = do
  portStr <- lookupEnv "SERVER_PORT"
  case portStr of
    Just s | all (`elem` ['0' .. '9']) s -> return $ fromInteger (read s)
    _ -> do
      putStrLn "Invalid SERVER_PORT; defaulting to 8080."
      return 8080

getCleanupInterval :: IO Int
getCleanupInterval = do
  intervalStr <- lookupEnv "CACHE_CLEAN_INTERVAL"
  case intervalStr of
    Just s | all (`elem` ['0' .. '9']) s -> return $ fromInteger (read s)
    _ -> do
      putStrLn "Invalid CACHE_CLEAN_INTERVAL; defaulting to 60 seconds."
      return 60

-- Application setup
app :: TVar Cache -> Application
app cacheTVar = serve fetchAPI (serverHandler cacheTVar)

fetchAPI :: Proxy API
fetchAPI = Proxy

-- Main Function
main :: IO ()
main = do
  port <- getPort
  cacheTVar <- initializeCache
  _ <- forkIO $ cleanupCache cacheTVar
  putStrLn $ "Running server on http://localhost:" ++ show port
  run port (app cacheTVar)

-- Environment Variables
-- export TTL_SECONDS=120
-- export SERVER_PORT=8080
-- export CACHE_CLEAN_INTERVAL=600