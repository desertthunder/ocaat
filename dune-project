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
  (cmarkit (= 0.4.0))
  lwt_ssl
  lwt_ppx
  ppx_blob
  mirage-crypto-rng
  yojson
  zarith
  uri))
