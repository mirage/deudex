val random_char : unit -> char

val report : unit -> unit
(** Set logs reporter at [Logs.Debug] level *)

(** Simple key/value modules with String type and a random constructor *)
module Key : sig
  include Index.Key with type t = string

  val v : unit -> t
end

module Value : sig
  include Index.Value with type t = string

  val v : unit -> t
end

module Index : Index.S with type key = Key.t and type value = Value.t

(** Helper constructors for fresh pre-initialised indices *)
module Make_context (Config : sig
  val root : string
end) : sig
  type t = {
    rw : Index.t;
    tbl : (string, string) Hashtbl.t;
    clone : readonly:bool -> Index.t;
  }

  val fresh_name : string -> string
  (** [fresh_name typ] is a clean directory for a resource of type [typ]. *)

  val empty_index : ?log_size:int -> unit -> t
  (** Fresh, empty index. *)

  val full_index : ?size:int -> ?log_size:int -> unit -> t
  (** Fresh index with a random table of key/value pairs, and a given
      constructor for opening clones of the index at the same location. *)
end
