(* Copyright (c) 2013-2017 The Labrys developers. *)
(* See the LICENSE file at the top-level directory. *)

open LambdaTree

module Set = Ident.Name.MSet

(* DEBUG:
let create_fresh_name =
  let n = ref (-1) in
  fun () ->
    incr n;
    LIdent.create (".@fresh." ^ string_of_int !n)
*)
let create_fresh_name () = LIdent.create ".@fresh"

let get_name name env =
  match EnvMap.Value.get name env with
  | Some x -> x
  | None -> assert false (* NOTE: Every external values should be in the
                            environment *)

let env_add name env =
  let id = LIdent.create (Ident.Name.to_string name) in
  (id, EnvMap.Value.add name id env)

let of_constr_rep env = function
  | UntypedTree.Index idx -> Index idx
  | UntypedTree.Exn name -> Exn (get_name name env)

let rec of_pattern ~unreachable env = function
  | UntypedTree.Jump label ->
      Jump label
  | UntypedTree.Switch (cases, default) ->
      let aux (constr, len, tree) =
        (of_constr_rep env constr, len, of_pattern ~unreachable env tree)
      in
      let cases = List.map aux cases in
      let default = match default with
        | Some default -> of_pattern ~unreachable env default
        | None -> Jump unreachable
      in
      Switch (cases, default)
  | UntypedTree.Alias (name, p) ->
      let name = get_name name env in
      Alias (name, of_pattern ~unreachable env p)
  | UntypedTree.Swap (idx, p) ->
      Swap (idx, of_pattern ~unreachable env p)

let create_dyn_functions f n =
  let rec aux params = function
    | 0 ->
        f params
    | n ->
        let name = LIdent.create (string_of_int n) in
        let params = params @ [name] in
        Abs (name, aux params (pred n))
  in
  aux [] n

let of_pat_vars env vars =
  let aux name (vars, env) =
    let (name, env) = env_add name env in
    (vars @ [name], env)
  in
  Ident.Name.Set.fold aux vars ([], env)

let rec get_lets env t = function
  | (name, x)::xs ->
      let (name, env) = env_add name env in
      Let (name, false, x, get_lets env t xs)
  | [] ->
      of_typed_term env t

and of_try_pattern env var l =
  let (branches, switch) =
    let rec aux i = function
      | [] ->
          ([], [])
      | ((exn, args), t)::xs ->
          let exn = get_name exn env in
          let (branches, switches) = aux (succ i) xs in
          let t =
            List.mapi (fun i x -> (x, RecordGet (var, i))) args
            |> get_lets env t
          in
          (t :: branches, (Exn exn, 0, Jump i) :: switches)
    in
    aux 0 l
  in
  let default = List.length branches in
  let branches = branches @ [Fail var] in
  let tree = Switch (switch, Jump default) in
  PatternMatching (var, [], branches, tree)

and of_args env f args =
  let args =
    let aux t =
      let name = create_fresh_name () in
      let t = of_typed_term env t in
      (name, t)
    in
    List.map aux args
  in
  let rec aux names = function
    | [] -> f (List.rev names)
    | (name, t)::args -> Let (name, false, t, aux (name :: names) args)
  in
  aux [] args

and of_typed_term env = function
  | UntypedTree.Abs (name, t) ->
      let (name, env) = env_add name env in
      let t = of_typed_term env t in
      Abs (name, t)
  | UntypedTree.App (f, x) ->
      let f = of_typed_term env f in
      let x = of_typed_term env x in
      let name_x = create_fresh_name () in
      let name_f = create_fresh_name () in
      Let (name_x, false, x, Let (name_f, false, f, App (name_f, name_x)))
  | UntypedTree.Val name ->
      Val (get_name name env)
  | UntypedTree.Var (rep, len) ->
      let rep = of_constr_rep env rep in
      create_dyn_functions
        (fun params -> Datatype (Some rep, params))
        len
  | UntypedTree.PatternMatching (t, vars, results, pattern) ->
      let t = of_typed_term env t in
      let name = create_fresh_name () in
      let (vars, env) = of_pat_vars env vars in
      let results = List.map (of_typed_term env) results in
      let unreachable = List.length results in
      let results = results @ [Unreachable] in
      let pattern = of_pattern ~unreachable env pattern in
      let pat = PatternMatching (name, vars, results, pattern) in
      Let (name, false, t, pat)
  | UntypedTree.Try (t, branches) ->
      let t = of_typed_term env t in
      let name = create_fresh_name () in
      let t' = of_try_pattern env name branches in
      Try (t, (name, t'))
  | UntypedTree.Let (name, t, xs) ->
      let t = of_typed_term env t in
      let (name, env) = env_add name env in
      let xs = of_typed_term env xs in
      Let (name, false, t, xs)
  | UntypedTree.LetRec (name, t, xs) ->
      let (name, env) = env_add name env in
      let t = of_typed_term env t in
      let xs = of_typed_term env xs in
      Let (name, true, t, xs)
  | UntypedTree.Fail t ->
      let name = create_fresh_name () in
      Let (name, false, of_typed_term env t, Fail name)
  | UntypedTree.RecordGet (t, n) ->
      let name = create_fresh_name () in
      let t = of_typed_term env t in
      Let (name, false, t, RecordGet (name, n))
  | UntypedTree.RecordCreate fields ->
      of_args env (fun names -> (Datatype (None, names))) fields
  | UntypedTree.Const const ->
      Const const

let create_dyn_functions cname options (ret, args) =
  match args with
  | [] ->
      (* TODO: See TypeChecker.get_foreign_type *)
      assert false
  | ty::args ->
      let rec aux args n = function
        | ty::xs ->
            let name = LIdent.create (string_of_int n) in
            let t = aux ((ty, name) :: args) (succ n) xs in
            Abs (name, t)
        | [] ->
            CallForeign (cname, options, ret, List.rev args)
      in
      let name = LIdent.create (string_of_int 0) in
      let t = aux [(ty, name)] 1 args in
      Abs (name, t)

let env_add mset name env =
  let mset = Set.remove mset name in
  let (name', linkage) = match Set.count mset name with
    | 0 -> (name, Public)
    | n -> (Ident.Name.unique name n, Private)
  in
  let id = LIdent.create (Ident.Name.to_string name') in
  let env = EnvMap.Value.add name id env in
  (id, mset, env, linkage)

let rec of_typed_tree mset env = function
  | UntypedTree.Value (name, t) :: xs ->
      let t = of_typed_term env t in
      let (name, mset, env, linkage) = env_add mset name env in
      let xs = of_typed_tree mset env xs in
      Value (name, t, linkage) :: xs
  | UntypedTree.Foreign (cname, options, name, ty) :: xs ->
      let (name, mset, env, linkage) = env_add mset name env in
      let xs = of_typed_tree mset env xs in
      Value (name, create_dyn_functions cname options ty, linkage) :: xs
  | UntypedTree.Exception name :: xs ->
      let (name, mset, env, _) = env_add mset name env in
      let xs = of_typed_tree mset env xs in
      Exception name :: xs
  | UntypedTree.Instance (name, values) :: xs ->
      (* TODO: Improve *)
      let values =
        let aux (name, x) t = UntypedTree.Let (name, x, t) in
        let fields = List.map (fun (x, _) -> UntypedTree.Val x) values in
        List.fold_right aux values (UntypedTree.RecordCreate fields)
      in
      let xs = UntypedTree.Value (name, values) :: xs in
      of_typed_tree mset env xs
  | [] ->
      []

let rec scan mset = function
  | UntypedTree.Value (name, _) :: xs
  | UntypedTree.Foreign (_, _, name, _) :: xs
  | UntypedTree.Instance (name, _) :: xs ->
      scan (Set.add mset name) xs
  | UntypedTree.Exception _ :: xs ->
      scan mset xs
  | [] ->
      mset

let of_typed_tree env top =
  let mset = scan Set.empty top in
  let env = Env.get_untyped_values env in
  of_typed_tree mset env top
