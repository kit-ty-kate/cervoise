(* Copyright (c) 2013-2017 The Labrys developers. *)
(* See the LICENSE file at the top-level directory. *)

type name = Ident.Name.t
type constr_name = Ident.Constr.t
type t_name = Ident.Type.t
type tyclass_name = Ident.TyClass.t
type instance_name = Ident.Instance.t
type module_name = Module.t
type loc = Location.t
type index = int

type foreign_options = DesugaredTree.foreign_options = {
  va_arg : index option;
}

type kind = DesugaredTree.kind =
  | KStar
  | KEff
  | KExn
  | KFun of (kind * kind)

type t_value = (t_name * kind)

type tyclass = (tyclass_name * t_value list * ty list)

and effects = (loc * ty list)

and ty' = DesugaredTree.ty' =
  | Fun of (ty * effects option * ty)
  | Ty of t_name
  | Eff of effects
  | Sum of ty list
  | Forall of (t_value * ty)
  | TyClass of (tyclass * effects option * ty)
  | AbsOnTy of (t_value * ty)
  | AppOnTy of (ty * ty)

and ty = (loc * ty')

type ty_annot = (ty * ty option)
type tyclass_instance = (tyclass_name * ty list)

type tyclass_app_arg = DesugaredTree.tyclass_app_arg =
  | TyClassVariable of instance_name
  | TyClassInstance of tyclass_instance

type pattern = DesugaredTree.pattern =
  | TyConstr of (loc * constr_name * pattern list)
  | Wildcard
  | Or of (pattern * pattern)
  | As of (pattern * name)

type const = DesugaredTree.const =
  | Int of int
  | Float of float
  | Char of Uchar.t
  | Bytes of string

type t' =
  | Abs of ((name * ty) * t)
  | TAbs of (t_value * t)
  | CAbs of ((instance_name * tyclass) * t)
  | App of (t * t)
  | TApp of (t * ty)
  | CApp of (t * tyclass_app_arg)
  | Val of name
  | Var of constr_name
  | PatternMatching of (t * (pattern * t) list)
  | Let of (name * t * t)
  | LetRec of (name * ty * t * t)
  | Fail of (ty * t)
  | Try of (t * ((constr_name * name list) * t) list)
  | Annot of (t * ty_annot)
  | Const of const

and t = (loc * t')

type variant = (constr_name * ty)

type top =
  | Value of (name * t)
  | Type of (t_name * ty)
  | Foreign of (string * foreign_options * name * ty)
  | Datatype of (t_name * kind * variant list)
  | Exception of (constr_name * ty)
  | Class of (tyclass_name * t_value list * (name * ty) list)
  | Instance of (tyclass_instance * instance_name option * (name * t) list)

type imports = module_name list

type interface = DesugaredTree.interface =
  | IVal of (name * ty)
  | IAbstractType of (t_name * kind)
  | IDatatype of (t_name * kind * variant list)
  | ITypeAlias of (t_name * ty)
  | IException of (constr_name * ty)
  | IClass of (tyclass_name * t_value list * (name * ty) list)
  | IInstance of (tyclass_instance * instance_name option)
