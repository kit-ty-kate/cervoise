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

open MonadOpen

type ty = (string * BackendType.t)

type t = ty Ast.ty

let rec to_string = function
  | Ast.Fun (Ast.Ty (x, _), ret) -> x ^ " -> " ^ to_string ret
  | Ast.Fun (x, ret) -> "(" ^ to_string x ^ ") -> " ^ to_string ret
  | Ast.Ty (x, _) -> x

let from_parse_tree gamma =
  let rec aux = function
    | Ast.Fun (x, y) ->
        aux x >>= fun x ->
        aux y >>= fun y ->
        Exn.return (Ast.Fun (x, y))
    | Ast.Ty name ->
        List.find (fun x -> Unsafe.(fst x = name)) gamma >>= fun x ->
        Exn.return (Ast.Ty x)
  in
  aux

let gamma =
  [ ("Int", BackendType.int)
  ]
