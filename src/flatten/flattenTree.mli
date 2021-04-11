(* Copyright (c) 2013-2017 The Labrys developers. *)
(* See the LICENSE file at the top-level directory. *)

type name = LIdent.t
type index = int
type constr = int
type length = int
type branch = int
type loc = Location.t

type foreign_options = LambdaTree.foreign_options = {
  va_arg : (loc * index) option;
}

type ('int, 'float, 'char, 'bytes) ty =
  ('int, 'float, 'char, 'bytes) LambdaTree.ty

type tag_ty = [(unit, unit, unit, unit) ty | `Custom]
type ret_ty = [tag_ty | `Void]
type const = (int, float, Uchar.t, string) ty

type constr_rep = LambdaTree.constr_rep = Index of constr | Exn of name

type tree = LambdaTree.tree =
  | Switch of ((constr_rep * length * tree) list * tree)
  | Swap of (index * tree)
  | Alias of (name * tree)
  | Jump of branch

type t' =
  | Abs of (name * t)
  | App of (name * name)
  | Val of name
  | Datatype of (constr_rep option * name list)
  | CallForeign of (string * foreign_options * ret_ty * (tag_ty * name) list)
  | PatternMatching of (name * name list * t list * tree)
  | Fail of name
  | Try of (t * (name * t))
  | RecordGet of (name * index)
  | Const of const
  | Unreachable

and t = ((name * bool * t') list * t')
(* NOTE: Please ignore the boolean outside of flatten.ml *)

type linkage = LambdaTree.linkage = Public | Private

type top =
  | Value of (name * t * linkage)
  | Exception of name
