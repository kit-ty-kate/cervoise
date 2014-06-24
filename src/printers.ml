(*
Copyright (c) 2013 Jacques-Pascal Deplaix <jp.deplaix@gmail.com>

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*)

open BatteriesExceptionless
open Monomorphic.None

let fmt = Printf.sprintf
let (^^) = PPrint.(^^)

let dump_name = Ident.Name.to_string
let dump_t_name = Ident.Type.to_string
let dump_k = Kinds.to_string

let rec dump_top f doc = function
  | [] -> doc
  | [x] -> doc ^^ f x
  | x::xs -> dump_top f (doc ^^ f x ^^ PPrint.hardline ^^ PPrint.hardline) xs

let string_of_doc doc =
  let buf = Buffer.create 1024 in
  PPrint.ToBuffer.pretty 0.9 80 buf doc;
  Buffer.contents buf

module ParseTree = struct
  open ParseTree

  let rec dump_ty = function
    | Fun (param, res) -> fmt "(%s -> %s)" (dump_ty param) (dump_ty res)
    | Ty name -> dump_t_name name
    | Forall ((name, k), res) ->
        fmt "(forall %s : %s, %s)" (dump_t_name name) (dump_k k) (dump_ty res)
    | AbsOnTy ((name, k), res) ->
        fmt "(λ (%s : %s) -> %s)" (dump_t_name name) (dump_k k) (dump_ty res)
    | AppOnTy (f, x) ->
        fmt "(%s [%s])" (dump_ty f) (dump_ty x)

  let rec dump_pattern = function
    | TyConstr (name, []) ->
        dump_name name
    | TyConstr (name, args) ->
        fmt
          "(%s %s)"
          (dump_name name)
          (String.concat " " (List.map dump_pattern_arg args))
    | Any name ->
        dump_name name

  and dump_pattern_arg = function
    | PVal p -> dump_pattern p
    | PTy ty -> fmt "[%s]" (dump_ty ty)

  let rec dump_t = function
    | Abs (_, (name, ty), t) ->
        PPrint.group
          (PPrint.lparen
           ^^ PPrint.string (fmt "λ (%s : %s) ->" (dump_name name) (dump_ty ty))
           ^^ PPrint.nest 2 (PPrint.break 1 ^^ dump_t t)
           ^^ PPrint.rparen
          )
    | TAbs (_, (name, k), t) ->
        PPrint.group
          (PPrint.lparen
           ^^ PPrint.string (fmt "λ (%s : %s) ->" (dump_t_name name) (dump_k k))
           ^^ PPrint.nest 2 (PPrint.break 1 ^^ dump_t t)
           ^^ PPrint.rparen
          )
    | App (_, f, x) ->
        PPrint.group
          (PPrint.lparen
           ^^ dump_t f
           ^^ PPrint.nest 2 (PPrint.break 1 ^^ dump_t x)
           ^^ PPrint.rparen
          )
    | TApp (_, f, ty) ->
        PPrint.group
          (PPrint.lparen
           ^^ dump_t f
           ^^ PPrint.blank 1
           ^^ PPrint.string (fmt "[%s]" (dump_ty ty))
           ^^ PPrint.rparen
          )
    | Val (_, name) ->
        PPrint.string (dump_name name)
    | PatternMatching (_, t, cases) ->
        PPrint.group
          (PPrint.string "match"
           ^^ PPrint.break 1
           ^^ dump_t t
           ^^ PPrint.break 1
           ^^ PPrint.string "with"
          )
        ^^ dump_cases cases
        ^^ PPrint.break 1
        ^^ PPrint.string "end"
    | Let (name, t, xs) ->
        PPrint.group
          (PPrint.lparen
           ^^ PPrint.string (fmt "let %s =" (dump_name name))
           ^^ PPrint.nest 2 (PPrint.break 1 ^^ dump_t t)
           ^^ PPrint.break 1
           ^^ PPrint.string "in"
           ^^ PPrint.break 1
           ^^ dump_t xs
           ^^ PPrint.rparen
          )
    | LetRec (_, name, ty, t, xs) ->
        PPrint.group
          (PPrint.lparen
           ^^ PPrint.string
                (fmt "let rec %s : %s =" (dump_name name) (dump_ty ty))
           ^^ PPrint.nest 2 (PPrint.break 1 ^^ dump_t t)
           ^^ PPrint.break 1
           ^^ PPrint.string "in"
           ^^ PPrint.break 1
           ^^ dump_t xs
           ^^ PPrint.rparen
          )

  and dump_cases cases =
    let aux doc ((_, pattern), (_, t)) =
      doc
      ^^ PPrint.break 1
      ^^ PPrint.group
           (PPrint.string (fmt "| %s ->" (dump_pattern pattern))
            ^^ PPrint.nest 4 (PPrint.break 1 ^^ dump_t t)
           )
    in
    List.fold_left aux PPrint.empty cases

  let dump_variants (Variant (_, name, ty)) =
    PPrint.string (fmt "| %s : %s" (dump_name name) (dump_ty ty))

  let dump_variants variants =
    let aux doc x = doc ^^ PPrint.break 1 ^^ dump_variants x in
    List.fold_left aux PPrint.empty variants

  let dump = function
    | Value (name, t) ->
        PPrint.group
          (PPrint.string (fmt "let %s =" (dump_name name))
           ^^ (PPrint.nest 2 (PPrint.break 1 ^^ dump_t t))
          )
    | RecValue (_, name, ty, t) ->
        PPrint.group
          (PPrint.string (fmt "let rec %s : %s =" (dump_name name) (dump_ty ty))
           ^^ PPrint.nest 2 (PPrint.break 1 ^^ dump_t t)
          )
    | Type (_, name, ty) ->
        PPrint.string (fmt "type alias %s = %s" (dump_t_name name) (dump_ty ty))
    | Binding (_, name, ty, content) ->
        PPrint.string (fmt "let %s : %s = begin" (dump_name name) (dump_ty ty))
        ^^ PPrint.string content
        ^^ PPrint.string "end"
    | Datatype (_, name, k, variants) ->
        PPrint.string (fmt "type %s : %s =" (dump_t_name name) (dump_k k))
        ^^ PPrint.nest 2 (dump_variants variants)

  let dump top =
    let doc = dump_top dump PPrint.empty top in
    string_of_doc doc
end

module TypedTree = struct
  open TypedTree

  let dump_pattern_matching t content =
    PPrint.group
      (PPrint.string "match"
       ^^ PPrint.break 1
       ^^ t
       ^^ PPrint.break 1
       ^^ PPrint.string "with"
      )
    ^^ content

  let rec dump_var = function
    | Pattern.VLeaf -> "VLeaf"
    | Pattern.VNode (i, var) -> fmt "VNode (%d, %s)" i (dump_var var)

  let rec dump_cases cases =
    let aux doc ((name, index), t) =
      doc
      ^^ PPrint.break 1
      ^^ PPrint.group
           (PPrint.string (fmt "| %s <=> %d ->" (dump_name name) index)
            ^^ PPrint.nest 4 (dump_patterns t)
           )

    in
    List.fold_left aux PPrint.empty cases

  and dump_patterns = function
    | Pattern.Leaf i ->
        PPrint.break 1
        ^^ PPrint.OCaml.int i
    | Pattern.Node (var, cases) ->
        dump_pattern_matching (PPrint.string (dump_var var)) (dump_cases cases)

  let dump_used_vars used_vars =
    let aux acc (var, name) =
      fmt "%s (%s = %s)" acc (dump_name name) (dump_var var)
    in
    List.fold_left aux "Ø" used_vars

  let rec dump_t = function
    | Abs (name, t) ->
        PPrint.group
          (PPrint.lparen
           ^^ PPrint.string (fmt "λ %s ->" (dump_name name))
           ^^ PPrint.nest 2 (PPrint.break 1 ^^ dump_t t)
           ^^ PPrint.rparen
          )
    | TAbs t ->
        PPrint.group
          (PPrint.lparen
           ^^ PPrint.string "λ ?? ->"
           ^^ PPrint.nest 2 (PPrint.break 1 ^^ dump_t t)
           ^^ PPrint.rparen
          )
    | App (f, x) ->
        PPrint.group
          (PPrint.lparen
           ^^ dump_t f
           ^^ PPrint.nest 2 (PPrint.break 1 ^^ dump_t x)
           ^^ PPrint.rparen
          )
    | TApp f ->
        PPrint.group
          (PPrint.lparen
           ^^ dump_t f
           ^^ PPrint.blank 1
           ^^ PPrint.string "[]"
           ^^ PPrint.rparen
          )
    | Val name ->
        PPrint.string (dump_name name)
    | PatternMatching (t, results, patterns) ->
        dump_pattern_matching
          (dump_t t)
          (dump_results results ^^ PPrint.break 1 ^^ dump_patterns patterns)
        ^^ PPrint.break 1
        ^^ PPrint.string "end"
    | Let (name, t, xs) ->
        PPrint.group
          (PPrint.lparen
           ^^ PPrint.string (fmt "let %s =" (dump_name name))
           ^^ PPrint.nest 2 (PPrint.break 1 ^^ dump_t t)
           ^^ PPrint.break 1
           ^^ PPrint.string "in"
           ^^ PPrint.break 1
           ^^ dump_t xs
           ^^ PPrint.rparen
          )
    | LetRec (name, t, xs) ->
        PPrint.group
          (PPrint.lparen
           ^^ PPrint.string (fmt "let %s =" (dump_name name))
           ^^ PPrint.nest 2 (PPrint.break 1 ^^ dump_t t)
           ^^ PPrint.break 1
           ^^ PPrint.string "in"
           ^^ PPrint.break 1
           ^^ dump_t xs
           ^^ PPrint.rparen
          )

  and dump_results results =
    let aux doc i (used_vars, result) =
      doc
      ^^ PPrint.break 1
      ^^ PPrint.group
           (PPrint.string (fmt "| %d with %s ->" i (dump_used_vars used_vars))
            ^^ PPrint.nest 4 (PPrint.break 1 ^^ dump_t result)
           )
    in
    List.fold_lefti aux PPrint.empty results

  let dump_variants (Variant (name, ty_size)) =
    PPrint.string (fmt "| %s of size %d" (dump_name name) ty_size)

  let dump_variants variants =
    let aux doc x = doc ^^ PPrint.break 1 ^^ dump_variants x in
    List.fold_left aux PPrint.empty variants

  let dump = function
    | Value (name, t) ->
        PPrint.group
          (PPrint.string (fmt "let %s =" (dump_name name))
           ^^ (PPrint.nest 2 (PPrint.break 1 ^^ dump_t t))
          )
    | RecValue (name, t) ->
        PPrint.group
          (PPrint.string (fmt "let rec %s =" (dump_name name))
           ^^ PPrint.nest 2 (PPrint.break 1 ^^ dump_t t)
          )
    | Binding (name, content) ->
        PPrint.string (fmt "let %s = begin" (dump_name name))
        ^^ PPrint.string content
        ^^ PPrint.string "end"
    | Datatype variants ->
        PPrint.string "type ?? ="
        ^^ PPrint.nest 2 (dump_variants variants)

  let dump top =
    let doc = dump_top dump PPrint.empty top in
    string_of_doc doc
end

module UntypedTree = struct
  open UntypedTree

  let dump_pattern_matching t content =
    PPrint.group
      (PPrint.string "match"
       ^^ PPrint.break 1
       ^^ t
       ^^ PPrint.break 1
       ^^ PPrint.string "with"
      )
    ^^ content

  let rec dump_var = function
    | Pattern.VLeaf -> "VLeaf"
    | Pattern.VNode (i, var) -> fmt "VNode (%d, %s)" i (dump_var var)

  let rec dump_cases cases =
    let aux doc (index, t) =
      doc
      ^^ PPrint.break 1
      ^^ PPrint.group
           (PPrint.string (fmt "| %d ->" index)
            ^^ PPrint.nest 4 (dump_patterns t)
           )

    in
    List.fold_left aux PPrint.empty cases

  and dump_patterns = function
    | Leaf i ->
        PPrint.break 1
        ^^ PPrint.OCaml.int i
    | Node (var, cases) ->
        dump_pattern_matching (PPrint.string (dump_var var)) (dump_cases cases)

  let dump_vars vars =
    let aux acc (var, name) =
      fmt "%s (%s = %s)" acc (dump_name name) (dump_var var)
    in
    List.fold_left aux "Ø" vars

  let dump_used_vars used_vars =
    let aux name acc =
      fmt "%s %s" acc (dump_name name)
    in
    Set.fold aux used_vars "Ø"

  let rec dump_t = function
    | Abs (name, used_vars, t) ->
        PPrint.group
          (PPrint.lparen
           ^^ PPrint.string
                (fmt "λ %s [%s] ->" (dump_name name) (dump_used_vars used_vars))
           ^^ PPrint.nest 2 (PPrint.break 1 ^^ dump_t t)
           ^^ PPrint.rparen
          )
    | App (f, x) ->
        PPrint.group
          (PPrint.lparen
           ^^ dump_t f
           ^^ PPrint.nest 2 (PPrint.break 1 ^^ dump_t x)
           ^^ PPrint.rparen
          )
    | Val name ->
        PPrint.string (dump_name name)
    | Variant index ->
        PPrint.OCaml.int index
    | PatternMatching (t, results, patterns) ->
        dump_pattern_matching
          (dump_t t)
          (dump_results results ^^ PPrint.break 1 ^^ dump_patterns patterns)
        ^^ PPrint.break 1
        ^^ PPrint.string "end"
    | Let (name, t, xs) ->
        PPrint.group
          (PPrint.lparen
           ^^ PPrint.string (fmt "let %s =" (dump_name name))
           ^^ PPrint.nest 2 (PPrint.break 1 ^^ dump_t t)
           ^^ PPrint.break 1
           ^^ PPrint.string "in"
           ^^ PPrint.break 1
           ^^ dump_t xs
           ^^ PPrint.rparen
          )
    | LetRec (name, t, xs) ->
        PPrint.group
          (PPrint.lparen
           ^^ PPrint.string (fmt "let %s =" (dump_name name))
           ^^ PPrint.nest 2 (PPrint.break 1 ^^ dump_t t)
           ^^ PPrint.break 1
           ^^ PPrint.string "in"
           ^^ PPrint.break 1
           ^^ dump_t xs
           ^^ PPrint.rparen
          )

  and dump_results results =
    let aux doc i (vars, result) =
      doc
      ^^ PPrint.break 1
      ^^ PPrint.group
           (PPrint.string (fmt "| %d with %s ->" i (dump_vars vars))
            ^^ PPrint.nest 4 (PPrint.break 1 ^^ dump_t result)
           )
    in
    List.fold_lefti aux PPrint.empty results

  let dump = function
    | Value (name, t) ->
        PPrint.group
          (PPrint.string (fmt "let %s =" (dump_name name))
           ^^ (PPrint.nest 2 (PPrint.break 1 ^^ dump_t t))
          )
    | RecValue (name, t) ->
        PPrint.group
          (PPrint.string (fmt "let rec %s =" (dump_name name))
           ^^ PPrint.nest 2 (PPrint.break 1 ^^ dump_t t)
          )
    | Binding (name, content) ->
        PPrint.string (fmt "let %s = begin" (dump_name name))
        ^^ PPrint.string content
        ^^ PPrint.string "end"

  let dump top =
    let doc = dump_top dump PPrint.empty top in
    string_of_doc doc
end
