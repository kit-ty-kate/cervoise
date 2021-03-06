(* Copyright (c) 2013-2017 The Labrys developers. *)
(* See the LICENSE file at the top-level directory. *)

type t

val make :
  modul:Module.t ->
  imports:Module.t list ->
  <debug : bool; ..> ->
  OptimizedTree.top list ->
  t

val link : <initial_heap_size : int; ..> -> main_module_name:Module.t -> main_module:t -> t Module.Map.t -> t

val optimize : <lto : bool; opt : int; ..> -> t -> t

val to_string : t -> string

exception BitcodeFailure

val write_bitcode : o:string -> t -> unit
val read_bitcode : string -> t

val emit_object_file : tmp:string -> t -> unit

val default_heap_size : int
