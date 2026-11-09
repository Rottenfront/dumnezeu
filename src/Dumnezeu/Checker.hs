module Dumnezeu.Checker where

import Dumnezeu.Generated.Odin.Abs qualified as Abs
import qualified Prelude as C (Eq, Ord, Show, Read)

data BasicType
  = BTInt8
  | BTInt16
  | BTInt32
  | BTInt64
  | BTUInt8
  | BTUInt16
  | BTUInt32
  | BTUInt64
  | BTFloat32
  | BTFloat64
  | BTBool
  | BTPointer BasicType
  | BTSlicePtr BasicType
  | BTStruct [BasicType]

data CheckError
  = ETypeMismatch 
