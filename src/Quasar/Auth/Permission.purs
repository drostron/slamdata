{-
Copyright 2016 SlamData, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
-}

module Quasar.Auth.Permission where

import Prelude

import Control.Monad.Aff (later')
import Control.Monad.Eff (Eff())
import Control.Monad.Eff.Random (random)
import Control.MonadPlus (guard)
import Control.UI.Browser (decodeURIComponent)

import Data.Functor.Eff (liftEff)
import Data.String as Str
import Data.String.Regex as Rgx
import Data.Maybe as M
import Data.Array as Arr
import Data.NonEmpty as Ne
import Data.Either as E

import DOM (DOM())
import DOM.HTML (window)
import DOM.HTML.Location as Location
import DOM.HTML.Window as Window

import Network.HTTP.RequestHeader (RequestHeader(..))

import SlamData.Effects (Slam())
import SlamData.FileSystem.Resource as R

import Utils.Path (FilePath())

newtype PermissionToken = PermissionToken String
runPermissionToken :: PermissionToken -> String
runPermissionToken (PermissionToken s) = s

type Permissions =
  {
    add :: Boolean
  , read :: Boolean
  , modify :: Boolean
  , delete :: Boolean
  }

isPermissionsEmpty
  :: Permissions
  -> Boolean
isPermissionsEmpty {add, read, modify, delete} =
  not (add || read || modify || delete)


newtype Group = Group FilePath
runGroup :: Group -> FilePath
runGroup (Group fp) = fp

newtype User = User String
runUser :: User -> String
runUser (User s) = s

type PermissionShareRequest =
  {
    resource :: R.Resource
  , targets :: E.Either (Ne.NonEmpty Array Group) (Ne.NonEmpty Array User)
  , permissions :: Permissions
  }

requestForGroups
  :: PermissionShareRequest
  -> Boolean
requestForGroups {targets} =
  E.isLeft targets

requestForUsers
  :: PermissionShareRequest
  -> Boolean
requestForUsers {targets} =
  E.isRight targets

permissionsHeader
  :: Array PermissionToken
  -> M.Maybe RequestHeader
permissionsHeader ps = do
  guard (not $ Arr.null ps)
  pure
    $ RequestHeader "X-Extra-PermissionTokens"
    $ Str.joinWith ","
    $ map runPermissionToken ps

retrievePermissionTokens
  :: forall e
   . Eff (dom :: DOM|e) (Array PermissionToken)
retrievePermissionTokens =
  window
    >>= Window.location
    >>= Location.search
    <#> permissionTokens
    <#> map PermissionToken
  where
  permissionRegex :: Rgx.Regex
  permissionRegex = Rgx.regex "permissionsToken=([^&]+)" Rgx.noFlags

  extractPermissionTokensString :: String -> M.Maybe String
  extractPermissionTokensString str =
    Rgx.match permissionRegex str
      >>= flip Arr.index 1
      >>= id
      <#> decodeURIComponent

  permissionTokens :: String -> Array String
  permissionTokens s =
    M.fromMaybe []
      $ Str.split ","
      <$> extractPermissionTokensString s

-- A mock for generating new tokens
genToken :: Slam PermissionToken
genToken =
  later' 1000 $ liftEff $ PermissionToken <$> show <$> random

-- One more mock
makePermissionShareRequest
  :: PermissionShareRequest
  -> Slam Unit
makePermissionShareRequest _ =
  later' 1000 $ pure unit
