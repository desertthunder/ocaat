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

(** The read-only Lexicon inspection skill shipped with this release. *)
let atproto_lexicons =
  {
    name = "atproto-lexicons";
    files =
      [
        file "SKILL.md" [%blob "../skills/atproto-lexicons/SKILL.md"];
        file "references/lexicon-workflows.md"
          [%blob "../skills/atproto-lexicons/references/lexicon-workflows.md"];
      ];
  }

(** Every skill embedded in the executable. *)
let all = [ atproto_research; atproto_lexicons ]
