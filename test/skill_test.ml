let fail message = raise (Failure message)
let assert_true label condition = if not condition then fail label
let assert_equal label expected actual = if expected <> actual then fail label

let contains haystack needle =
  let needle_length = String.length needle in
  let last_start = String.length haystack - needle_length in
  let rec loop index =
    if index > last_start then false
    else if String.sub haystack index needle_length = needle then true
    else loop (index + 1)
  in
  needle_length = 0 || loop 0

let () =
  let skill =
    match Ocaat__Skill.all with
    | [ skill ] -> skill
    | _ -> fail "expected one bundled skill"
  in
  assert_equal "bundled skill name" "atproto-research" skill.Ocaat__Skill.name;
  assert_equal "bundled file count" 3 (List.length skill.Ocaat__Skill.files);
  let paths =
    List.map (fun file -> file.Ocaat__Skill.path) skill.Ocaat__Skill.files
  in
  assert_equal "bundled file paths"
    [ "SKILL.md"; "references/discovery.md"; "references/provenance.md" ]
    paths;
  List.iter
    (fun file ->
      assert_true
        (file.Ocaat__Skill.path ^ " is not embedded")
        (String.length file.Ocaat__Skill.contents > 0))
    skill.Ocaat__Skill.files;
  let skill_md = List.hd skill.Ocaat__Skill.files in
  assert_true "skill metadata is embedded"
    (contains skill_md.Ocaat__Skill.contents "name: atproto-research");
  assert_true "planned discovery boundary is embedded"
    (contains (List.nth skill.Ocaat__Skill.files 1).Ocaat__Skill.contents
       "General collection discovery across repositories");
  assert_true "provenance contract is embedded"
    (contains (List.nth skill.Ocaat__Skill.files 2).Ocaat__Skill.contents
       "fetched_at");
  print_endline "skill embedding tests passed"
