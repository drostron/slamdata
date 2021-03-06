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

module SlamData.Notebook.FormBuilder.Item.Component
  ( Query(..)
  , UpdateQuery(..)
  , module SlamData.Notebook.FormBuilder.Item.Component.State
  , itemComponent
  ) where

import Prelude

import Control.Bind ((=<<))

import Data.Either as E
import Data.Foldable as F
import Data.Lens ((^?), (.~), (?~))
import Data.Lens as Lens
import Data.Maybe as M

import Halogen
import Halogen.HTML.Events.Indexed as HE
import Halogen.HTML.Indexed as H
import Halogen.HTML.Properties.Indexed as HP

import SlamData.Notebook.FormBuilder.Item.Component.State
import SlamData.Notebook.FormBuilder.Item.FieldType

data UpdateQuery a
  = UpdateName String a
  | UpdateFieldType String a
  | UpdateDefaultValue String a

data Query a
  = Update (UpdateQuery a)
  | SetModel Model a
  | GetModel (Model -> a)

type ItemHTML = ComponentHTML Query
type ItemDSL g = ComponentDSL State Query g

itemComponent
  :: forall g
   . (Functor g)
  => Component State Query g
itemComponent =
  component render eval

render
  :: State
  -> ComponentHTML Query
render { model } =
  H.tr_ $
    [ H.td_ [ nameField ]
    , H.td_ [ typeField ]
    , H.td_ [ defaultField ]
    ]

  where
    nameField :: ComponentHTML Query
    nameField =
      H.input
        [ HP.inputType HP.InputText
        , HP.title "Field Name"
        , HP.value model.name
        , HE.onValueChange (HE.input \str -> Update <<< UpdateName str)
        ]

    typeField :: ComponentHTML Query
    typeField =
      H.select
        [ HE.onValueChange (HE.input \str -> Update <<< UpdateFieldType str)
        ]
        (typeOption <$> allFieldTypes)

    typeOption
      :: FieldType
      -> ComponentHTML Query
    typeOption ty =
      H.option
        [ HP.selected $ ty == model.fieldType ]
        [ H.text $ Lens.review _FieldTypeDisplayName ty ]

    defaultField :: ComponentHTML Query
    defaultField =
      case model.fieldType of
        BooleanFieldType ->
          H.div_
            [ H.input
                [ HP.inputType inputType
                , HP.id_ inputId
                , HP.checked $ M.fromMaybe false $ Lens.preview _StringBoolean =<< model.defaultValue
                , HE.onChecked $ HE.input \str -> Update <<< UpdateDefaultValue (Lens.review _StringBoolean str)
                ]
            , H.label [ HP.for inputId ] [ H.text model.name ]
            ]
        _ ->
          H.input
            [ HP.inputType inputType
            , HP.id_ inputId
            , HP.value $ M.fromMaybe "" model.defaultValue
            , HE.onValueChange $ HE.input \str -> Update <<< UpdateDefaultValue str
            ]
      where
        inputType =
          fieldTypeToInputType model.fieldType
        inputId =
          model.name <> "-defaultValue"


    _StringBoolean :: Lens.PrismP String Boolean
    _StringBoolean = Lens.prism re pre
      where
        re b = if b then "true" else "false"
        pre "true" = E.Right true
        pre "false" = E.Right false
        pre str = E.Left str

eval :: forall g. Natural Query (ItemDSL g)
eval q =
  case q of
    Update q ->
      evalUpdate q
    SetModel m next -> do
      modify $ _model .~ m
      pure next
    GetModel k ->
      k <<< Lens.view _model <$> get

evalUpdate :: forall g. Natural UpdateQuery (ItemDSL g)
evalUpdate q =
  case q of
    UpdateName str next -> do
      modify $ _model <<< _name .~ str
      pure next
    UpdateFieldType str next -> do
      F.for_ (str ^? _FieldTypeDisplayName) \ty -> do
        modify $ _model <<< _fieldType .~ ty
      pure next
    UpdateDefaultValue str next -> do
      modify $ _model <<< _defaultValue ?~ str
      pure next
