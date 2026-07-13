type file = { path : string; contents : string }
(** A file shipped as part of an embedded agent skill. *)

type t = { name : string; files : file list }
(** A complete read-only agent skill and its bundled reference files. *)

(** Construct one embedded skill file with its installed relative path. *)
let file path contents = { path; contents }

(** The evidence-oriented research skill shipped with this release. *)
let atproto_research =
  {
    name = "atproto-research";
    files =
      [
        file "SKILL.md" [%blob "../skills/atproto-research/SKILL.md"];
        file "references/discovery.md"
          [%blob "../skills/atproto-research/references/discovery.md"];
        file "references/provenance.md"
          [%blob "../skills/atproto-research/references/provenance.md"];
      ];
  }

(** Every skill embedded in the executable. Add later skills here. *)
let all = [ atproto_research ]
