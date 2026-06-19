(lang dune 3.13)

(name ocaat)

(generate_opam_files true)

(package
 (name ocaat)
 (synopsis "OCaml AT Protocol PDS admin CLI")
 (description
  "Admin CLI for Tempest PDS.")
 (depends
  (ocaml (>= 5.1))
  (dune (>= 3.13))
  cmdliner
  fmt
  logs
  cohttp-lwt-unix
  lwt_ssl
  lwt_ppx
  yojson
  uri))
