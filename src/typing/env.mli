(* Copyright (c) 2013-2017 The Labrys developers. *)
(* See the LICENSE file at the top-level directory. *)

val empty : TypedEnv.env
val union : TypedEnv.env -> TypedEnv.env -> TypedEnv.env
val diff : TypedEnv.env -> TypedEnv.env -> TypedEnv.env
val get_untyped_values : TypedEnv.env -> LIdent.t EnvMap.Value.t

val check_vdiff : TypedEnv.env -> TypedEnv.env -> unit

type add = TypedEnv.env -> TypedEnv.env

val add_value : Ident.Name.t -> TypedEnv.nty -> add
val add_abstract_type : Ident.Type.t -> PretypedTree.kind -> add
val add_datatype :
  Ident.Type.t ->
  PretypedTree.kind ->
  PretypedTree.variant list ->
  add
val add_type_alias : Ident.Type.t -> PretypedTree.ty -> add
val add_exception : Ident.Constr.t -> PretypedTree.ty -> add
