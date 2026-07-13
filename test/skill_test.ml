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
  assert_equal "bundled skill count" 2 (List.length Ocaat__Skill.all);
  let find_skill name =
    match
      List.find_opt
        (fun skill -> skill.Ocaat__Skill.name = name)
        Ocaat__Skill.all
    with
    | Some skill -> skill
    | None -> fail ("missing bundled skill: " ^ name)
  in
  let research = find_skill "atproto-research" in
  assert_equal "research file count" 3 (List.length research.Ocaat__Skill.files);
  let research_paths =
    List.map (fun file -> file.Ocaat__Skill.path) research.Ocaat__Skill.files
  in
  assert_equal "research file paths"
    [ "SKILL.md"; "references/discovery.md"; "references/provenance.md" ]
    research_paths;
  let lexicons = find_skill "atproto-lexicons" in
  assert_equal "lexicons file count" 2 (List.length lexicons.Ocaat__Skill.files);
  let lexicon_paths =
    List.map (fun file -> file.Ocaat__Skill.path) lexicons.Ocaat__Skill.files
  in
  assert_equal "lexicons file paths"
    [ "SKILL.md"; "references/lexicon-workflows.md" ]
    lexicon_paths;
  List.iter
    (fun skill ->
      List.iter
        (fun file ->
          assert_true
            (skill.Ocaat__Skill.name ^ ": " ^ file.Ocaat__Skill.path
           ^ " is not embedded")
            (String.length file.Ocaat__Skill.contents > 0))
        skill.Ocaat__Skill.files)
    Ocaat__Skill.all;
  let research_skill_md = List.hd research.Ocaat__Skill.files in
  assert_true "research skill metadata is embedded"
    (contains research_skill_md.Ocaat__Skill.contents "name: atproto-research");
  assert_true "planned discovery boundary is embedded"
    (contains (List.nth research.Ocaat__Skill.files 1).Ocaat__Skill.contents
       "General collection discovery across repositories");
  assert_true "provenance contract is embedded"
    (contains (List.nth research.Ocaat__Skill.files 2).Ocaat__Skill.contents
       "fetched_at");
  let lexicon_skill_md = List.hd lexicons.Ocaat__Skill.files in
  assert_true "lexicons skill metadata is embedded"
    (contains lexicon_skill_md.Ocaat__Skill.contents "name: atproto-lexicons");
  assert_true "lexicon workflow is embedded"
    (contains (List.nth lexicons.Ocaat__Skill.files 1).Ocaat__Skill.contents
       "Authority resolution");
  assert_true "planned Lexicon work is embedded"
    (contains lexicon_skill_md.Ocaat__Skill.contents "compatibility analysis");
  print_endline "skill embedding tests passed"
