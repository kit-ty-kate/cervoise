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

type t =
  { values : Types.t GammaMap.Value.t
  ; types : Types.visibility GammaMap.Types.t
  ; constructors : ((Types.t * int) GammaMap.Index.t) GammaMap.Constr.t
  ; exceptions : Types.t list GammaMap.Exn.t
  ; effects : GammaMap.Eff.t
  }

let empty =
  { values = GammaMap.Value.empty
  ; types = GammaMap.Types.empty
  ; constructors = GammaMap.Constr.empty
  ; exceptions = GammaMap.Exn.empty
  ; effects = GammaMap.Eff.of_list Builtins.effects
  }

let add_value k x self = {self with values = GammaMap.Value.add k x self.values}
let add_type ~loc k x self = {self with types = GammaMap.Types.add ~loc k x self.types}
let add_constr k k2 x self = {self with constructors = GammaMap.Constr.add k k2 x self.constructors}
let add_exception ~loc k x self = {self with exceptions = GammaMap.Exn.add ~loc k x self.exceptions}
let add_effect ~loc k self = {self with effects = GammaMap.Eff.add ~loc k self.effects}

let union (modul, a) b =
  { values = GammaMap.Value.union (modul, a.values) b.values
  ; types = GammaMap.Types.union (modul, a.types) b.types
  ; constructors = GammaMap.Constr.union (modul, a.constructors) b.constructors
  ; exceptions = GammaMap.Exn.union (modul, a.exceptions) b.exceptions
  ; effects = b.effects
  }

let ty_equal x y = match x, y with
  | (Types.Abstract k1 | Types.Alias (_, k1)), Types.Abstract k2
  | Types.Abstract k1, Types.Alias (_, k2) ->
      Kinds.equal k1 k2
  | Types.Alias (ty1, k1), Types.Alias (ty2, k2) ->
      Types.equal ty1 ty2 && Kinds.equal k1 k2

let constr_equal (x, y) (x', y') = Types.equal x x' && Int.equal y y'

let is_subset_of a b =
  GammaMap.Value.diff ~eq:Types.equal a.values b.values
  @ GammaMap.Types.diff ~eq:ty_equal a.types b.types
  @ GammaMap.Constr.diff ~eq:(GammaMap.Index.equal constr_equal) a.constructors b.constructors
  @ GammaMap.Exn.diff ~eq:(List.eq Types.equal) a.exceptions b.exceptions
