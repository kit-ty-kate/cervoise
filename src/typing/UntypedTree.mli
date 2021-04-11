(* Copyright (c) 2013-2017 The Labrys developers. *)
(* See the LICENSE file at the top-level directory. *)

type name = Ident.Name.t
type pat_vars = Ident.Name.Set.t
type index = int
type length = int
type branch = int
type loc = Location.t

type foreign_options = PretypedTree.foreign_options = {
  va_arg : (loc * index) option;
}

type ('int, 'float, 'char, 'bytes) ty = [
  | `Int of 'int
  | `Float of 'float
  | `Char of 'char
  | `Bytes of 'bytes
]

type tag_ty = [(unit, unit, unit, unit) ty | `Custom]
type ret_ty = [tag_ty | `Void]
type const = (int, float, Uchar.t, string) ty

type constr_rep = Index of index | Exn of name

type tree =
  (* TODO: Do we need the default case ? *)
  | Switch of ((constr_rep * length * tree) list * tree option)
  | Swap of (index * tree)
  | Alias of (name * tree)
  | Jump of branch

type t =
  | Abs of (name * t)
  | App of (t * t)
  | Val of name
  | Var of (constr_rep * length)
  | PatternMatching of (t * pat_vars * t list * tree)
  | Let of (name * t * t)
  | LetRec of (name * t * t)
  | Fail of t
  | Try of (t * ((name * name list) * t) list)
  | RecordGet of (t * int)
  | RecordCreate of t list
  | Const of const

type foreign_fun_type = (ret_ty * tag_ty list)

type top =
  | Value of (name * t)
  | Foreign of (string * foreign_options * name * foreign_fun_type)
  | Exception of name
  | Instance of (name * (name * t) list)
