(* Copyright (c) 2013-2017 The Labrys developers. *)
(* See the LICENSE file at the top-level directory. *)

open OptimizedTree

module Set = LIdent.MSet

let rec of_term' = function
  | FlattenTree.Abs (name, t) ->
      let (t, fv) = of_term t in
      let fv = Set.remove_all fv name in
      (Abs (name, fv, t), fv)
  | FlattenTree.App (x, y) ->
      (App (x, y), Set.of_list [x; y])
  | FlattenTree.Val name ->
      (Val name, Set.singleton name)
  | FlattenTree.Datatype (idx, args) ->
      (Datatype (idx, args), Set.of_list args)
  | FlattenTree.CallForeign (name, options, ty, args) ->
      let fv = List.fold_right (fun (_, name) fv -> Set.add fv name) args Set.empty in
      (CallForeign (name, options, ty, args), fv)
  | FlattenTree.PatternMatching (name, vars, branches, tree) ->
      let (branches, fv) = of_branches branches in
      let fv = List.fold_left Set.remove_all fv vars in
      (PatternMatching (name, vars, branches, tree), Set.add fv name)
  | FlattenTree.Fail name ->
      (Fail name, Set.singleton name)
  | FlattenTree.Try (t, (name, t')) ->
      let (t, fv1) = of_term t in
      let (t', fv2) = of_term t' in
      let fv2 = Set.remove_all fv2 name in
      (Try (t, (name, t')), Set.union fv1 fv2)
  | FlattenTree.RecordGet (name, idx) ->
      (RecordGet (name, idx), Set.singleton name)
  | FlattenTree.Const c ->
      (Const c, Set.empty)
  | FlattenTree.Unreachable ->
      (Unreachable, Set.empty)

and of_term (lets, t) =
  let rec aux = function
    | (name, _, x)::xs ->
        let (x, fv1) = of_term' x in
        let (lets, t, fv2) = aux xs in
        begin match x, Set.count fv2 name with
        | (Abs _ | Val _ | Datatype _ | Const _), 0 ->
            (lets, t, fv2)
        | _ ->
            let fv = Set.remove_all (Set.union fv1 fv2) name in
            ((name, x) :: lets, t, fv)
        end
    | [] ->
        let (t, fv) = of_term' t in
        ([], t, fv)
  in
  let (lets, t, fv) = aux lets in
  ((lets, t), fv)

and of_branches branches =
  let aux (acc, fv) t =
    let (t, fvt) = of_term t in
    (t :: acc, Set.union fvt fv)
  in
  let (branches, fv) = List.fold_left aux ([], Set.empty) branches in
  (List.rev branches, fv)

let of_flatten_tree tree =
  let aux = function
    (* TODO: OptimizedTree.Function is unused *)
    | FlattenTree.Value (name, t, linkage) ->
        let (t, _) = of_term t in
        Value (name, t, linkage)
    | FlattenTree.Exception exn ->
        Exception exn
  in
  List.map aux tree
