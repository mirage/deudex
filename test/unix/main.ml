open Common

let ( // ) = Filename.concat

let root = "_tests" // "unix.main"

module Context = Common.Make_context (struct
  let root = root
end)

let main = Context.full_index ()

(* Helper functions *)
let rec random_new_key tbl =
  let r = Key.v () in
  if Hashtbl.mem tbl r then random_new_key tbl else r

let check_entry findf k v =
  match findf k with
  | v' when v = v' -> ()
  | v' (* v =/= v' *) ->
      Alcotest.failf "Wrong insertion: found %s when expected %s at key %s." v'
        v k
  | exception Not_found ->
      Alcotest.failf "Wrong insertion: %s key is missing." k

let check_index_entry index = check_entry (Index.find index)

let check_tbl_entry tbl = check_entry (Hashtbl.find tbl)

let check_equivalence index htbl =
  Hashtbl.iter (check_index_entry index) htbl;
  Index.iter (check_tbl_entry htbl) index

let test_replace t =
  let k = Key.v () in
  let v = Value.v () in
  let v' = Value.v () in
  Index.replace t k v;
  Index.replace t k v';
  check_index_entry t k v'

let test_find_absent t tbl =
  let rec loop i =
    if i = 0 then ()
    else
      let k = random_new_key tbl in
      Alcotest.check_raises (Printf.sprintf "Absent value was found: %s." k)
        Not_found (fun () -> ignore (Index.find t k));
      loop (i - 1)
  in
  loop 100

(* Basic tests of find/replace on a live index *)
module Live = struct
  let find_present_live () =
    let { Context.rw; tbl; _ } = Context.full_index () in
    check_equivalence rw tbl

  let find_absent_live () =
    let { Context.rw; tbl; _ } = Context.full_index () in
    test_find_absent rw tbl

  let replace_live () =
    let { Context.rw; _ } = Context.full_index () in
    test_replace rw

  let different_size_for_key () =
    let { Context.rw; _ } = Context.empty_index () in
    let k = String.init 2 (fun _i -> random_char ()) in
    let v = Value.v () in
    let exn = Index.Invalid_key_size k in
    Alcotest.check_raises
      "Cannot add a key of a different size than string_size." exn (fun () ->
        Index.replace rw k v)

  let different_size_for_value () =
    let { Context.rw; _ } = Context.empty_index () in
    let k = Key.v () in
    let v = String.init 200 (fun _i -> random_char ()) in
    let exn = Index.Invalid_value_size v in
    Alcotest.check_raises
      "Cannot add a value of a different size than string_size." exn (fun () ->
        Index.replace rw k v)

  let tests =
    [
      ("find (present)", `Quick, find_present_live);
      ("find (absent)", `Quick, find_absent_live);
      ("replace", `Quick, replace_live);
      ("fail add (key)", `Quick, different_size_for_key);
      ("fail add (value)", `Quick, different_size_for_value);
    ]
end

(* Tests of behaviour after restarting the index *)
module DuplicateInstance = struct
  let find_present () =
    let Context.{ tbl; clone; _ } = Context.full_index () in
    let rw = clone ~readonly:false in
    check_equivalence rw tbl

  let find_absent () =
    let Context.{ tbl; clone; _ } = Context.full_index () in
    let rw = clone ~readonly:false in
    test_find_absent rw tbl

  let replace () =
    let Context.{ clone; _ } = Context.full_index ~size:5 () in
    let rw = clone ~readonly:false in
    test_replace rw

  let tests =
    [
      ("find (present)", `Quick, find_present);
      ("find (absent)", `Quick, find_absent);
      ("replace", `Quick, replace);
    ]
end

(* Tests of read-only indices *)
module Readonly = struct
  let readonly () =
    let { Context.rw; clone; _ } = Context.empty_index () in
    let ro = clone ~readonly:true in
    Hashtbl.iter (fun k v -> Index.replace rw k v) main.tbl;
    Index.flush rw;
    check_equivalence ro main.tbl

  let readonly_clear () =
    let { Context.rw; tbl; clone } = Context.full_index () in
    let r = clone ~readonly:true in
    check_equivalence r tbl;
    Index.clear rw;
    Hashtbl.iter
      (fun k _ ->
        Alcotest.check_raises (Printf.sprintf "Found %s key after clearing." k)
          Not_found (fun () -> ignore (Index.find r k)))
      tbl

  (* a readonly index can create an empty_index *)
  let start_ro () =
    let ro = Index.v ~fresh:false ~readonly:true ~log_size:4 "empty_index" in
    Index.close ro

  let tests =
    [
      ("add", `Quick, readonly);
      ("read after clear", `Quick, readonly_clear);
      ("start readonly with empty index", `Quick, start_ro);
    ]
end

(* Tests of {Index.close} *)
module Close = struct
  let close_reopen_rw () =
    let { Context.rw; tbl; clone } = Context.full_index () in
    Index.close rw;
    let w = clone ~readonly:false in
    check_equivalence w tbl;
    Index.close w

  let find_absent () =
    let Context.{ rw; tbl; clone; _ } = Context.full_index () in
    Index.close rw;
    let rw = clone ~readonly:false in
    test_find_absent rw tbl;
    Index.close rw

  let replace () =
    let Context.{ rw; clone; _ } = Context.full_index ~size:5 () in
    Index.close rw;
    let rw = clone ~readonly:false in
    test_replace rw;
    Index.close rw

  let open_readonly_close_rw () =
    let { Context.rw; tbl; clone } = Context.full_index () in
    let ro = clone ~readonly:true in
    Index.close rw;
    check_equivalence ro tbl;
    Index.close ro

  let close_reopen_readonly () =
    let { Context.rw; tbl; clone } = Context.full_index () in
    Index.close rw;
    let ro = clone ~readonly:true in
    check_equivalence ro tbl;
    Index.close ro

  let test_read_after_close t k tbl =
    check_equivalence t tbl;
    Index.close t;
    Alcotest.check_raises "Read after close raises Not_found" Not_found
      (fun () -> ignore (Index.find t k))

  let test_read_after_close_readonly t k tbl =
    check_equivalence t tbl;
    Index.close t;
    let exn = Unix.Unix_error (Unix.EBADF, "read", "") in
    Alcotest.check_raises "Cannot read in readonly index after close." exn
      (fun () -> ignore (Index.find t k))

  let fail_read_after_close () =
    let { Context.rw; tbl; _ } = Context.full_index () in
    let k, v = (Key.v (), Value.v ()) in
    Index.replace rw k v;
    Hashtbl.replace tbl k v;
    test_read_after_close rw k tbl

  let fail_write_after_close () =
    let { Context.rw; _ } = Context.empty_index () in
    Index.close rw;
    let k, v = (Key.v (), Value.v ()) in
    (* a single add does not fail*)
    Index.replace rw k v;
    let exn = Unix.Unix_error (Unix.EBADF, "read", "") in
    Alcotest.check_raises "Cannot write in index after close." exn (fun () ->
        Hashtbl.iter (fun k v -> Index.replace rw k v) main.tbl)

  let open_twice () =
    let { Context.rw; tbl; clone } = Context.full_index () in
    let w1 = rw in
    let w2 = clone ~readonly:false in
    let k, v = (Key.v (), Value.v ()) in
    Index.replace w1 k v;
    Hashtbl.replace tbl k v;
    Index.close w1;

    (* while another instance is still open, read does not fail*)
    check_equivalence w1 tbl;
    test_read_after_close w2 k tbl

  let open_twice_readonly () =
    let { Context.rw; tbl; clone } = Context.full_index () in
    let k, v = (Key.v (), Value.v ()) in
    Index.replace rw k v;
    Hashtbl.replace tbl k v;
    Index.close rw;
    let ro1 = clone ~readonly:true in
    let ro2 = clone ~readonly:true in
    check_equivalence ro1 tbl;
    Index.close ro1;
    test_read_after_close_readonly ro2 k tbl

  let tests =
    [
      ("close and reopen", `Quick, close_reopen_rw);
      ("find (absent)", `Quick, find_absent);
      ("replace", `Quick, replace);
      ("open two instances, close one", `Quick, open_readonly_close_rw);
      ("close and reopen on readonly", `Quick, close_reopen_readonly);
      ("fail to read after close", `Quick, fail_read_after_close);
      ("fail to write after close", `Quick, fail_write_after_close);
      ("open twice same instance", `Quick, open_twice);
      ("open twice same instance readonly", `Quick, open_twice_readonly);
    ]
end

let () =
  Common.report ();
  Alcotest.run "index.unix"
    [
      ("io_array", Io_array.tests);
      ("merge", Force_merge.tests);
      ("live", Live.tests);
      ("on restart", DuplicateInstance.tests);
      ("readonly", Readonly.tests);
      ("close", Close.tests);
    ]
