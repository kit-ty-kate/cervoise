(*
Copyright (c) 2013-2015 Jacques-Pascal Deplaix <jp.deplaix@gmail.com>

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

exception Error of string

type t =
  { path : string
  ; file : string
  }

let create_aux modul =
  let base_filename = Ident.Module.to_file modul in
  let path = Filename.dirname base_filename in
  let path = if String.equal path "." then "" else path in
  let file = Filename.basename (base_filename ^ ".sfw") in
  {path; file}

let create =
  let regexp = Str.regexp "[A-Z][a-zA-Z]+" in
  fun modul ->
    let modul = String.nsplit modul ~by:"." in
    let is_correct str =
      if not (Str.string_match regexp str 0) then
        raise (Error "The name of the module given is not correct.");
    in
    List.iter is_correct modul;
    create_aux (Ident.Module.of_list modul)

let of_module ~parent_module modul =
  let {path; file} = create_aux modul in
  let path = Filename.concat parent_module.path path in
  {path; file}

let impl {path; file} =
  Filename.concat path file

let intf self =
  let file = impl self in
  file ^ "i"

let to_module {path; file} =
  let file = Filename.concat path file in
  let file = Filename.chop_extension file in
  let file = String.nsplit file ~by:Filename.dir_sep in
  let file = List.map String.capitalize file in
  Ident.Module.of_list file
