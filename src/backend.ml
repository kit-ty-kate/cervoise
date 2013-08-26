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

module TT = TypedTree

open MonadOpen

let m = LLVM.create_module Types.context "Main"

let find_in_gamma name l =
  let c = ref 0 in
  List.find (fun x -> incr c; Unsafe.(fst x = name)) l >|= fun res ->
  (res, !c)

let i64 = LLVM.const_int (LLVM.i64_type Types.context)

let rec lambda gammaParam gammaEnv gammaGlob builder = function
  | TT.Abs ({TT.abs_ty; TT.param; TT.ty_expr}, t) ->
      let args = [| Types.to_llvm param.TT.ty; Types.env |] in
      let ty = LLVM.function_type (Types.to_llvm ty_expr) args in
      let f = LLVM.define_function "__lambda" ty m in
      let access =
        LLVM.build_malloc
          (Types.to_llvm ~malloc:true abs_ty)
          "access_fun"
          builder
      in
      (* store f and env *)
      let builder = LLVM.builder_at_end Types.context (LLVM.entry_block f) in
      let gammaP = [(param.TT.name, LLVM.param f 0)] in
      let gammaE = (param.TT.name, f) in
      lambda gammaP (gammaE :: gammaEnv) gammaGlob builder t >>= fun v ->
      ignore (LLVM.build_ret v builder);
      Exn.return access
  | TT.App (ty, f, x) ->
      lambda gammaParam gammaEnv gammaGlob builder f >>= fun boxed_f ->
      let boxed_f = LLVM.build_load boxed_f "exctract_f" builder in
      let f = LLVM.build_extractvalue boxed_f 0 "f" builder in
      let env = LLVM.build_extractvalue boxed_f 1 "env" builder in
      lambda gammaParam gammaEnv gammaGlob builder x >>= fun x ->
      Exn.return (LLVM.build_call f [| x; env |] "tmp" builder)
  | TT.Val {TT.name; TT.ty} ->
      let find gamma =
        find_in_gamma name gamma >|= fun (res, c) -> (snd res, c)
      in
      let execEnv (f, c) =
        let param = LLVM.param f 1 in
        LLVM.build_load (LLVM.build_gep param [| i64 c |] "from_env" builder) "loading_from_env" builder
      in
      let execGlob (value, _) =
        LLVM.build_load value "glob_extract" builder
      in
      let cast value =
        LLVM.build_bitcast value (Types.to_llvm ty) "cast" builder
      in
      let res = find gammaParam >|= fst in
      let res = Exn.catch res (fun `NotFound -> find gammaEnv >|= execEnv >|= cast) in
      let res = Exn.catch res (fun `NotFound -> find gammaGlob >|= execGlob) in
      res

let rec init gammaGlob builder = function
  | (name, g, t) :: xs ->
      lambda [] [] gammaGlob builder t >>= fun value ->
      ignore (LLVM.build_store value g builder);
      init ((name, g) :: gammaGlob) builder xs
  | [] -> Exn.return ()

let print =
  let rec top init_list = function
    | TT.Value ({TT.name; TT.ty}, t) :: xs ->
        let g = LLVM.define_global name (LLVM.undef (Types.to_llvm ty)) m in
        top ((name, g, t) :: init_list) xs
    | [] ->
        let ty = LLVM.function_type (LLVM.void_type Types.context) [||] in
        let f = LLVM.define_function "__init" ty m in
        let builder = LLVM.builder_at_end Types.context (LLVM.entry_block f) in
        init [] builder (List.rev init_list) >>= fun () ->
        ignore (LLVM.build_ret_void builder);
        LLVM.dump_module m;
        Exn.return ()
  in
  top []
