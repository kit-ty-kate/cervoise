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

let sprintf = Printf.sprintf

type args =
  { print : bool
  ; lto : bool
  ; opt : int
  ; c : bool
  ; o : string option
  ; file : string
  }

exception ParseError of string

let compile {c; o; file; _} result =
  let o = match o with
    | Some o -> o
    | None -> if c then Utils.replace_ext file "o" else "a.out"
  in
  let c = if c then "-c" else "" in
  let o = Filename.quote o in
  let command = sprintf "llc-3.5 - | cc %s -x assembler - -o %s" c o in
  let output = Unix.open_process_out command in
  output_string output result;
  match Unix.close_process_out output with
  | Unix.WEXITED 0 -> ()
  | _ -> prerr_endline "\nThe compilation processes exited abnormally"

let print_or_compile = function
  | {print = true; _} -> print_endline
  | {print = false; _} as args -> compile args

let rec parse file =
  let (imports, program) =
    let file = open_in file in
    let aux () =
      let filebuf = Lexing.from_channel file in
      let get_offset () =
        let pos = Lexing.lexeme_start_p filebuf in
        let open Lexing in
        let column = pos.pos_cnum - pos.pos_bol in
        string_of_int pos.pos_lnum ^ ":" ^ string_of_int column
      in
      try Parser.main Lexer.main filebuf with
      | Lexer.Error ->
          raise (ParseError ("Lexing error at: " ^ get_offset ()))
      | Parser.Error ->
          raise (ParseError ("Parsing error at: " ^ get_offset ()))
    in
    finally (fun () -> close_in file) aux ()
  in
  let aux acc x =
    assert false
  in
  let gamma = List.fold_left aux Gamma.empty imports in
  (gamma, program)

and compile args =
  parse args.file
  |> TypeChecker.from_parse_tree
  |> Lambda.of_typed_tree
  |> Backend.make ~with_main:(not args.c) ~lto:args.lto ~opt:args.opt
  |> Llvm.string_of_llmodule
  |> print_or_compile args