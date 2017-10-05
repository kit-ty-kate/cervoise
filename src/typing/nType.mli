(* Copyright (c) 2013-2017 The Cervoise developers. *)
(* See the LICENSE file at the top-level directory. *)

val check :
  pure_arrow:[`Partial | `Forbid | `Allow] ->
  TypedEnv.env ->
  PretypedTree.ty ->
  TypedEnv.nty

val check_eff :
  pure_arrow:[`Partial | `Forbid | `Allow] ->
  TypedEnv.env ->
  PretypedTree.ty ->
  TypedEnv.neffects

val is_subset_of : TypedEnv.nty -> TypedEnv.nty -> bool
val eff_is_subset_of : TypedEnv.neffects -> TypedEnv.neffects -> bool
val aty_is_subset_of : TypedEnv.aty -> TypedEnv.aty -> bool

val to_type : TypedEnv.nty -> TypedEnv.ty
val size : TypedEnv.nty -> int
val replace : Ident.Type.t -> by:TypedEnv.ty -> TypedEnv.nty -> TypedEnv.nty
val funs :
  TypedEnv.nty -> ((TypedEnv.nty * TypedEnv.neffects) list * TypedEnv.nty)

val dump : TypedEnv.nty -> PPrint.document
val dump_eff : TypedEnv.neffects -> PPrint.document
val dump_aty : Ident.Type.t -> TypedEnv.aty -> PPrint.document
val dump_constr :
  Ident.Constr.t -> (TypedEnv.constr_rep * TypedEnv.nty) -> PPrint.document
