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

module SlamData.Dialog.Share.User.Component where

import Prelude

import Control.Monad (when)
import Control.MonadPlus (guard)

import Data.Foldable as F
import Data.Functor (($>))
import Data.Functor.Eff (liftEff)
import Data.Lens (LensP(), lens, (.~), (%~), (?~))
import Data.Lens.Index (ix)
import Data.Map as Map
import Data.Maybe as M
import Data.Time (Milliseconds(..))
import Data.Tuple as Tpl

import DOM.HTML.Types (HTMLElement())

import Halogen
import Halogen.HTML.Indexed as H
import Halogen.HTML.Events.Indexed as E
import Halogen.HTML.Properties.Indexed as P
import Halogen.HTML.Properties.Indexed.ARIA as ARIA
import Halogen.Themes.Bootstrap3 as B
import Halogen.CustomProps as Cp
import Halogen.Component.Utils (forceRerender, sendAfter)

import SlamData.Effects (Slam())
import SlamData.Render.CSS as Rc
import SlamData.Render.Common (glyph, fadeWhen)

import Utils.DOM (focus)

type State =
  {
    inputs :: Map.Map Int String
  , elements :: Map.Map Int HTMLElement
  , blurred :: M.Maybe Int
  }

_inputs :: forall a r. LensP {inputs :: a|r} a
_inputs = lens _.inputs _{inputs = _}

_elements :: forall a r. LensP {elements :: a|r} a
_elements = lens _.elements _{elements = _}

_blurred :: forall a r. LensP {blurred :: a|r} a
_blurred = lens _.blurred _{blurred = _}

initialState :: State
initialState =
  {
    inputs: Map.empty
  , elements: Map.empty
  , blurred: M.Nothing
  }

data Query a
  = InputChanged Int String a
  | Remove Int a
  | Blurred Int a
  | Create Int a
  | Focused (M.Maybe Int) a
  | RememberEl Int HTMLElement a
  | GetValues (Array String -> a)

type UserShareDSL = ComponentDSL State Query Slam

comp :: Component State Query Slam
comp = component render eval

render :: State -> ComponentHTML Query
render state =
  H.form
    [ Cp.nonSubmit
    , P.classes [ Rc.userShareForm ]
    ]
    ((F.foldMap (Tpl.uncurry showInput) $ Map.toList state.inputs)
     <> [ newInput newKey ]
    )
  where
  mbMaxKey :: M.Maybe Int
  mbMaxKey = F.maximum $ Map.keys state.inputs

  newKey :: Int
  newKey =
    M.fromMaybe zero $ add one mbMaxKey

  shouldFade :: Boolean
  shouldFade =
    mbMaxKey
      >>= flip Map.lookup state.inputs
      <#> eq ""
      # M.fromMaybe false

  showInput :: Int -> String -> Array (ComponentHTML Query)
  showInput inx val =
    [ H.div [ P.classes [ B.inputGroup ] ]
      [
        H.input [ P.classes [ B.formControl ]
                , P.value val
                , ARIA.label "User email or name"
                , E.onValueInput (E.input (InputChanged inx))
                , E.onBlur (E.input_ (Blurred inx))
                , E.onFocus (E.input_ (Focused $ M.Just inx))
                , P.key $ show inx
                , P.initializer (\el -> action $ RememberEl inx el)
                ]
      , H.span [ P.classes [ B.inputGroupBtn ] ]
        [ H.button
          [ P.classes ([ B.btn ] <> (guard (val /= "") $> B.btnDefault))
          , E.onClick (E.input_ (Remove inx))
          , P.buttonType P.ButtonButton
          , P.disabled (val == "")
          , ARIA.label "Clear user email or name"
          ]
          [ glyph B.glyphiconRemove ]
        ]
      ]
     ]

  newInput :: Int -> ComponentHTML Query
  newInput inx =
    H.div [ P.classes ([ B.inputGroup ] <> fadeWhen shouldFade) ]
      [
        H.input [ P.classes [ B.formControl ]
                , ARIA.label "User email or name"
                , E.onFocus (E.input_ (Create inx))
                , P.value ""
                , P.key $ show inx
                , P.initializer (\el -> action $ RememberEl inx el)
                ]
      , H.span [ P.classes [ B.inputGroupBtn ] ]
        [ H.button
          [ P.classes [ B.btn ]
          , P.disabled true
          , P.buttonType P.ButtonButton
          , ARIA.label "Clear user email or name"
          ]
          [ glyph B.glyphiconRemove ]
        ]
      ]


eval :: Natural Query UserShareDSL
eval (Create inx next) = do
  clearBlurred $ pure unit
  modify $ _inputs %~ Map.insert inx ""
  forceRerender
  focusInx inx
  pure next
eval (InputChanged inx val next) = modify (_inputs <<< ix inx .~ val) $> next
eval (Remove inx next) = forgetInx inx $> next
eval (Focused mbInx next) = do
  clearBlurred do
    forceRerender
    F.for_ mbInx focusInx
  pure next
eval (Blurred inx next) = do
  modify $ _blurred ?~ inx
  sendAfter (Milliseconds 200.0) $ action $ Focused M.Nothing
  pure next
eval (RememberEl inx el next) = modify (_elements %~ Map.insert inx el) $> next
eval (GetValues continue) =
  gets _.inputs <#> Map.values <#> F.foldMap pure <#> continue


forgetInx
  :: Int
  -> UserShareDSL Unit
forgetInx inx = do
  modify $ _inputs %~ Map.delete inx
  modify $ _elements %~ Map.delete inx

focusInx
  :: Int
  -> UserShareDSL Unit
focusInx inx =
  gets _.elements
    <#> Map.lookup inx
    >>= F.traverse_ (liftEff <<< focus)

clearBlurred
  :: UserShareDSL Unit
  -> UserShareDSL Unit
clearBlurred act =
  gets _.blurred >>= F.traverse_ \bix -> do
    val <-
      gets _.inputs
      <#> Map.lookup bix
      <#> M.fromMaybe ""
    when (val == "") $ forgetInx bix
    modify $ _blurred .~ M.Nothing
    act
