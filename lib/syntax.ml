(** Result of a syntax check.

    [Valid] means the value matches the atproto string format; [Invalid reason]
    is intended for CLI diagnostics. *)
type check = Valid | Invalid of string

let is_alpha = function 'a' .. 'z' | 'A' .. 'Z' -> true | _ -> false
let is_lower_alpha = function 'a' .. 'z' -> true | _ -> false
let is_digit = function '0' .. '9' -> true | _ -> false
let is_alnum c = is_alpha c || is_digit c

let is_hex = function
  | '0' .. '9' | 'a' .. 'f' | 'A' .. 'F' -> true
  | _ -> false

let starts_with ~prefix value =
  let prefix_len = String.length prefix in
  String.length value >= prefix_len && String.sub value 0 prefix_len = prefix

let contains_char needle value =
  let rec loop index =
    index < String.length value && (value.[index] = needle || loop (index + 1))
  in
  loop 0

let split_on_char needle value =
  let rec loop start index acc =
    if index = String.length value then
      List.rev (String.sub value start (index - start) :: acc)
    else if value.[index] = needle then
      loop (index + 1) (index + 1)
        (String.sub value start (index - start) :: acc)
    else loop start (index + 1) acc
  in
  loop 0 0 []

let rec last = function
  | [] -> None
  | [ value ] -> Some value
  | _ :: rest -> last rest

let validate_hostname_label label =
  let len = String.length label in
  if len = 0 then Invalid "empty hostname segment"
  else if len > 63 then Invalid "hostname segment is longer than 63 characters"
  else if label.[0] = '-' || label.[len - 1] = '-' then
    Invalid "hostname segment cannot start or end with '-'"
  else
    let rec loop index =
      if index = len then Valid
      else
        let c = label.[index] in
        if is_alnum c || c = '-' then loop (index + 1)
        else Invalid "hostname segment contains an invalid character"
    in
    loop 0

(** Validate a Lexicon [handle] string.

    This follows the atproto Handle syntax:
    - ASCII hostname form
    - at most 253 characters
    - at least two dot-separated segments
    - 1-63 characters per segment
    - labels made from letters/digits/hyphen
    - no leading/trailing hyphens
    - a final top-level segment that does not start with a digit. *)
let validate_handle value =
  let len = String.length value in
  let parts = split_on_char '.' value in
  if len = 0 then Invalid "handle is empty"
  else if len > 253 then Invalid "handle is longer than 253 characters"
  else if List.length parts < 2 then
    Invalid "handle must contain at least two segments"
  else
    let rec loop = function
      | [] -> (
          match last parts with
          | Some tld when is_digit tld.[0] ->
              Invalid "handle top-level segment cannot start with a digit"
          | _ -> Valid)
      | label :: rest -> (
          match validate_hostname_label label with
          | Valid -> loop rest
          | Invalid reason -> Invalid reason)
    in
    loop parts

(** Validate a Lexicon [did] string.

    This accepts generic atproto DID identifier syntax, not only currently
    blessed DID methods.

    The method must be lowercase letters, the value must start with [did:],
    query/fragment/path syntax is rejected, and the maximum atproto length is
    2048 characters. *)
let validate_did value =
  let len = String.length value in
  if len > 2048 then Invalid "DID is longer than 2048 characters"
  else if not (starts_with ~prefix:"did:" value) then
    Invalid "DID must start with did:"
  else
    match split_on_char ':' value with
    | "did" :: method_ :: identifier_parts ->
        if method_ = "" then Invalid "DID method is empty"
        else if not (String.for_all is_lower_alpha method_) then
          Invalid "DID method must contain only lowercase letters"
        else if identifier_parts = [] then Invalid "DID identifier is empty"
        else
          let identifier = String.concat ":" identifier_parts in
          let identifier_len = String.length identifier in
          if identifier_len = 0 then Invalid "DID identifier is empty"
          else if
            identifier.[identifier_len - 1] = ':'
            || identifier.[identifier_len - 1] = '%'
          then Invalid "DID identifier cannot end with ':' or '%'"
          else
            let rec loop index =
              if index = identifier_len then Valid
              else
                match identifier.[index] with
                | '/' | '?' | '#' ->
                    Invalid
                      "DID identifier cannot contain path, query, or fragment \
                       syntax"
                | '%' ->
                    if index + 2 >= identifier_len then
                      Invalid "DID percent escape is incomplete"
                    else if
                      is_hex identifier.[index + 1]
                      && is_hex identifier.[index + 2]
                    then loop (index + 3)
                    else
                      Invalid "DID percent escape must have two hex characters"
                | 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '.' | '_' | ':' | '-'
                  ->
                    loop (index + 1)
                | _ -> Invalid "DID identifier contains an invalid character"
            in
            loop 0
    | _ -> Invalid "DID must have did:<method>:<identifier> shape"

let validate_nsid_authority_part ~first part =
  let len = String.length part in
  if len = 0 then Invalid "empty NSID segment"
  else if len > 63 then Invalid "NSID segment is longer than 63 characters"
  else if part.[0] = '-' || part.[len - 1] = '-' then
    Invalid "NSID authority segment cannot start or end with '-'"
  else if first && is_digit part.[0] then
    Invalid "NSID first authority segment cannot start with a digit"
  else
    let rec loop index =
      if index = len then Valid
      else
        let c = part.[index] in
        if is_alnum c || c = '-' then loop (index + 1)
        else Invalid "NSID authority segment contains an invalid character"
    in
    loop 0

(** Validate a Lexicon [nsid] string.

    NSIDs are reverse-domain identifiers followed by a case-sensitive name
    segment.

    This checks the 317-character maximum, at least three segments, handle-like
    domain authority rules in reverse order, and a final name made of ASCII
    letters/digits with a non-digit first character. *)
let validate_nsid value =
  let len = String.length value in
  let parts = split_on_char '.' value in
  if len > 317 then Invalid "NSID is longer than 317 characters"
  else
    match parts with
    | _ :: _ :: _ :: _ ->
        let rec split_name = function
          | [] -> ([], "")
          | [ name ] -> ([], name)
          | part :: rest ->
              let authority, name = split_name rest in
              (part :: authority, name)
        in
        let authority, name = split_name parts in
        let authority_len = String.length (String.concat "." authority) in
        let name_len = String.length name in
        if authority_len > 253 then
          Invalid "NSID authority is longer than 253 characters"
        else if name_len = 0 then Invalid "NSID name is empty"
        else if name_len > 63 then
          Invalid "NSID name is longer than 63 characters"
        else if not (is_alpha name.[0]) then
          Invalid "NSID name must start with a letter"
        else
          let rec loop_name index =
            if index = name_len then Valid
            else if is_alnum name.[index] then loop_name (index + 1)
            else Invalid "NSID name contains an invalid character"
          in
          let rec loop_authority first = function
            | [] -> loop_name 0
            | part :: rest -> (
                match validate_nsid_authority_part ~first part with
                | Valid -> loop_authority false rest
                | Invalid reason -> Invalid reason)
          in
          loop_authority true authority
    | _ -> Invalid "NSID must contain at least three dot-separated segments"

(** Validate a Lexicon [record-key] string.

    This checks the generic "any" record key syntax:
    - 1-512 ASCII characters
    - only [A-Za-z0-9.-_:~]
    - not the special values [.] or [..]. *)
let validate_rkey value =
  let len = String.length value in
  if len = 0 then Invalid "record key is empty"
  else if len > 512 then Invalid "record key is longer than 512 characters"
  else if value = "." || value = ".." then
    Invalid "record key cannot be '.' or '..'"
  else
    let rec loop index =
      if index = len then Valid
      else
        match value.[index] with
        | 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '.' | '-' | '_' | ':' | '~' ->
            loop (index + 1)
        | _ -> Invalid "record key contains an invalid character"
    in
    loop 0

(** Validate a Lexicon [at-uri] string.

    This checks the restricted Lexicon AT URI form:
    - [at://AUTHORITY[/COLLECTION[/RKEY]]]
    - with handle-or-DID authority
    - NSID collection
    - record-key rkey
    - no query/fragment
    - no trailing slash. *)
let validate_at_uri value =
  if String.length value > 8192 then Invalid "AT URI is longer than 8 KiB"
  else if not (starts_with ~prefix:"at://" value) then
    Invalid "AT URI must start with at://"
  else if contains_char '?' value || contains_char '#' value then
    Invalid "AT URI lexicon format does not allow query or fragment"
  else
    let path = String.sub value 5 (String.length value - 5) in
    let validate_authority authority =
      if starts_with ~prefix:"did:" authority then validate_did authority
      else validate_handle authority
    in
    match split_on_char '/' path with
    | [ authority ] when authority <> "" -> validate_authority authority
    | [ authority; "" ] when authority <> "" ->
        Invalid "AT URI cannot have a trailing slash"
    | [ authority; collection ] when authority <> "" && collection <> "" -> (
        match validate_authority authority with
        | Invalid reason -> Invalid ("authority is invalid: " ^ reason)
        | Valid -> (
            match validate_nsid collection with
            | Valid -> Valid
            | Invalid reason -> Invalid ("collection NSID is invalid: " ^ reason)
            ))
    | [ authority; collection; rkey ]
      when authority <> "" && collection <> "" && rkey <> "" -> (
        match validate_authority authority with
        | Invalid reason -> Invalid ("authority is invalid: " ^ reason)
        | Valid -> (
            match validate_nsid collection with
            | Invalid reason -> Invalid ("collection NSID is invalid: " ^ reason)
            | Valid -> (
                match validate_rkey rkey with
                | Valid -> Valid
                | Invalid reason -> Invalid ("record key is invalid: " ^ reason)
                )))
    | _ ->
        Invalid
          "AT URI must include an authority and optional collection/rkey path"

let base32_value = function
  | 'a' -> Some 0
  | 'b' -> Some 1
  | 'c' -> Some 2
  | 'd' -> Some 3
  | 'e' -> Some 4
  | 'f' -> Some 5
  | 'g' -> Some 6
  | 'h' -> Some 7
  | 'i' -> Some 8
  | 'j' -> Some 9
  | 'k' -> Some 10
  | 'l' -> Some 11
  | 'm' -> Some 12
  | 'n' -> Some 13
  | 'o' -> Some 14
  | 'p' -> Some 15
  | 'q' -> Some 16
  | 'r' -> Some 17
  | 's' -> Some 18
  | 't' -> Some 19
  | 'u' -> Some 20
  | 'v' -> Some 21
  | 'w' -> Some 22
  | 'x' -> Some 23
  | 'y' -> Some 24
  | 'z' -> Some 25
  | '2' -> Some 26
  | '3' -> Some 27
  | '4' -> Some 28
  | '5' -> Some 29
  | '6' -> Some 30
  | '7' -> Some 31
  | _ -> None

let decode_base32_no_padding value =
  let len = String.length value in
  let bytes = Buffer.create (len * 5 / 8) in
  let rec loop index bits bit_count =
    if index = len then
      if bit_count > 0 && bits land ((1 lsl bit_count) - 1) <> 0 then
        Error "CID base32 padding bits must be zero"
      else Ok (Buffer.contents bytes)
    else
      match base32_value value.[index] with
      | None -> Error "CID contains a non-base32 character"
      | Some value ->
          let bits = (bits lsl 5) lor value in
          let bit_count = bit_count + 5 in
          if bit_count >= 8 then (
            let bit_count = bit_count - 8 in
            Buffer.add_char bytes (Char.chr ((bits lsr bit_count) land 0xff));
            loop (index + 1) (bits land ((1 lsl bit_count) - 1)) bit_count)
          else loop (index + 1) bits bit_count
  in
  loop 0 0 0

let byte_at bytes index = Char.code bytes.[index]

(** Validate a Lexicon [cid] string for atproto's blessed CID set.

    The atproto Data Model blesses CIDv1, base32 string encoding with [b]
    multibase prefix, [raw] or DRISL/DAG-CBOR codecs, and sha2-256 multihash.

    This validator decodes enough CID bytes to enforce those constraints. *)
let validate_cid value =
  let len = String.length value in
  if len < 2 then Invalid "CID is too short"
  else if value.[0] <> 'b' then
    Invalid "CID must use lowercase base32 multibase prefix 'b'"
  else
    match decode_base32_no_padding (String.sub value 1 (len - 1)) with
    | Error reason -> Invalid reason
    | Ok bytes ->
        if String.length bytes <> 36 then
          Invalid "CID must encode a 36-byte atproto CID"
        else if byte_at bytes 0 <> 0x01 then Invalid "CID version must be 1"
        else if byte_at bytes 1 <> 0x55 && byte_at bytes 1 <> 0x71 then
          Invalid "CID codec must be raw or dag-cbor"
        else if byte_at bytes 2 <> 0x12 then
          Invalid "CID multihash must be sha2-256"
        else if byte_at bytes 3 <> 0x20 then
          Invalid "CID multihash length must be 32 bytes"
        else Valid

let tid_alphabet = "234567abcdefghijklmnopqrstuvwxyz"
let tid_first_alphabet = "234567abcdefghij"
let is_tid_char c = contains_char c tid_alphabet

(** Validate a Lexicon [tid] string.

    TIDs are 13-character base32-sortable strings using
    [234567abcdefghijklmnopqrstuvwxyz].

    The first character is restricted to [234567abcdefghij] so the top bit of
    the 64-bit value is not set. *)
let validate_tid value =
  let len = String.length value in
  if len <> 13 then Invalid "TID must be 13 characters"
  else if not (contains_char value.[0] tid_first_alphabet) then
    Invalid "TID first character is out of range"
  else
    let rec loop index =
      if index = len then Valid
      else if is_tid_char value.[index] then loop (index + 1)
      else Invalid "TID contains an invalid character"
    in
    loop 1

(** Generate a syntactically valid atproto TID.

    The generated 64-bit value stores current microseconds since the Unix epoch
    in the top 53 timestamp bits and a 10-bit random clock identifier in the low
    bits.

    This keeps generation simple so it does not yet guarantee monotonicity
    across multiple calls in the same microsecond. *)
let generate_tid () =
  Random.self_init ();
  let micros = Int64.of_float (Unix.gettimeofday () *. 1_000_000.) in
  let clock_id = Int64.of_int (Random.bits () land 0x3ff) in
  let value = Int64.(logor (shift_left micros 10) clock_id) in
  let bytes = Bytes.make 13 tid_alphabet.[0] in
  let rec loop index value =
    if index >= 0 then (
      let digit = Int64.(to_int (logand value 31L)) in
      Bytes.set bytes index tid_alphabet.[digit];
      loop (index - 1) Int64.(shift_right_logical value 5))
  in
  loop 12 value;
  Bytes.unsafe_to_string bytes

let is_two_digits value index =
  index + 1 < String.length value
  && is_digit value.[index]
  && is_digit value.[index + 1]

let is_four_digits value index =
  is_two_digits value index && is_two_digits value (index + 2)

let int2 value index =
  ((Char.code value.[index] - Char.code '0') * 10)
  + (Char.code value.[index + 1] - Char.code '0')

let leap_year year = year mod 4 = 0 && (year mod 100 <> 0 || year mod 400 = 0)

let days_in_month year = function
  | 1 | 3 | 5 | 7 | 8 | 10 | 12 -> 31
  | 4 | 6 | 9 | 11 -> 30
  | 2 -> if leap_year year then 29 else 28
  | _ -> 0

let validate_timezone value index =
  let len = String.length value in
  if index >= len then Invalid "datetime timezone is missing"
  else if value.[index] = 'Z' && index = len - 1 then Valid
  else if (value.[index] = '+' || value.[index] = '-') && index + 6 = len then
    if not (is_two_digits value (index + 1) && is_two_digits value (index + 4))
    then Invalid "datetime timezone offset must use HH:MM"
    else if value.[index + 3] <> ':' then
      Invalid "datetime timezone offset must use HH:MM"
    else if
      value.[index] = '-'
      && int2 value (index + 1) = 0
      && int2 value (index + 4) = 0
    then Invalid "datetime timezone cannot be -00:00"
    else if int2 value (index + 1) > 23 then
      Invalid "datetime timezone hour is out of range"
    else if int2 value (index + 4) > 59 then
      Invalid "datetime timezone minute is out of range"
    else Valid
  else Invalid "datetime timezone must be Z or +/-HH:MM"

(** Validate a Lexicon [datetime] string.

    This checks the atproto intersection of RFC 3339, ISO 8601, and WHATWG:
    [YYYY-MM-DDTHH:MM:SS], optional fractional seconds, and required uppercase
    [Z] or numeric timezone offset.

    Lowercase [t]/[z], missing seconds, missing timezone, and [-00:00] are
    rejected. *)
let validate_datetime value =
  let len = String.length value in
  if len < 20 then Invalid "datetime is too short"
  else if not (is_four_digits value 0) then
    Invalid "datetime year must have four digits"
  else if value.[4] <> '-' || value.[7] <> '-' then
    Invalid "datetime date must use YYYY-MM-DD"
  else if value.[10] <> 'T' then
    Invalid "datetime must separate date and time with T"
  else if not (is_two_digits value 5 && is_two_digits value 8) then
    Invalid "datetime month and day must have two digits"
  else if
    not
      (is_two_digits value 11 && is_two_digits value 14
     && is_two_digits value 17)
  then Invalid "datetime time must use HH:MM:SS"
  else if value.[13] <> ':' || value.[16] <> ':' then
    Invalid "datetime time must use HH:MM:SS"
  else
    let year = (int2 value 0 * 100) + int2 value 2 in
    let month = int2 value 5 in
    let day = int2 value 8 in
    let hour = int2 value 11 in
    let minute = int2 value 14 in
    let second = int2 value 17 in
    if month < 1 || month > 12 then Invalid "datetime month is out of range"
    else if day < 1 || day > days_in_month year month then
      Invalid "datetime day is out of range"
    else if hour > 23 then Invalid "datetime hour is out of range"
    else if minute > 59 then Invalid "datetime minute is out of range"
    else if second > 60 then Invalid "datetime second is out of range"
    else if value.[19] = '.' then
      let rec loop_fraction index =
        if index >= len then Invalid "datetime timezone is missing"
        else if is_digit value.[index] then loop_fraction (index + 1)
        else if index = 20 then
          Invalid "datetime fractional seconds cannot be empty"
        else validate_timezone value index
      in
      loop_fraction 20
    else validate_timezone value 19

(** Return the current UTC time as an atproto datetime string. *)
let datetime_now () =
  let tm = Unix.gmtime (Unix.time ()) in
  Printf.sprintf "%04d-%02d-%02dT%02d:%02d:%02dZ" (tm.tm_year + 1900)
    (tm.tm_mon + 1) tm.tm_mday tm.tm_hour tm.tm_min tm.tm_sec

let validate_service_url value =
  if String.length value = 0 then Invalid "URL is empty"
  else
    let uri = Uri.of_string value in
    match Uri.scheme uri with
    | Some ("http" | "https") -> (
        match Uri.host uri with
        | None | Some "" -> Invalid "URL must include a host"
        | Some _ -> (
            match Uri.userinfo uri with
            | Some _ -> Invalid "URL must not include credentials"
            | None -> (
                match Uri.verbatim_query uri with
                | Some _ -> Invalid "URL must not include a query string"
                | None -> (
                    match Uri.fragment uri with
                    | Some _ -> Invalid "URL must not include a fragment"
                    | None ->
                        let path = Uri.path uri in
                        if path = "" || path = "/" then Valid
                        else Invalid "URL path must be empty or /"))))
    | Some _ -> Invalid "URL scheme must be http or https"
    | None -> Invalid "URL must include a scheme"

let validate_artifact_path value =
  let len = String.length value in
  if len = 0 then Invalid "artifact path is empty"
  else
    let rec loop index =
      if index = len then Valid
      else if value.[index] = '\000' then
        Invalid "artifact path cannot contain NUL"
      else loop (index + 1)
    in
    loop 0

let is_language_alpha value start stop =
  let rec loop index =
    if index = stop then true
    else if is_alpha value.[index] then loop (index + 1)
    else false
  in
  loop start

let validate_language_subtag value =
  let len = String.length value in
  if len = 0 then Invalid "language tag contains an empty subtag"
  else if len > 8 then Invalid "language subtag is longer than 8 characters"
  else
    let rec loop index =
      if index = len then Valid
      else if is_alnum value.[index] then loop (index + 1)
      else Invalid "language subtag contains an invalid character"
    in
    loop 0

let validate_language value =
  let len = String.length value in
  if len = 0 then Invalid "language tag is empty"
  else if len > 128 then Invalid "language tag is longer than 128 characters"
  else
    match split_on_char '-' value with
    | [] -> Invalid "language tag is empty"
    | [ "x" ] | [ "X" ] ->
        Invalid "private-use language tag is missing a subtag"
    | ("x" | "X") :: subtags ->
        let rec loop = function
          | [] -> Valid
          | subtag :: rest -> (
              match validate_language_subtag subtag with
              | Valid -> loop rest
              | Invalid reason -> Invalid reason)
        in
        loop subtags
    | primary :: subtags ->
        let primary_len = String.length primary in
        if primary_len < 2 || primary_len > 8 then
          Invalid "language primary subtag must be 2 to 8 letters"
        else if not (is_language_alpha primary 0 primary_len) then
          Invalid "language primary subtag must contain only letters"
        else
          let rec loop = function
            | [] -> Valid
            | subtag :: rest -> (
                match validate_language_subtag subtag with
                | Valid -> loop rest
                | Invalid reason -> Invalid reason)
          in
          loop subtags

(** Dispatch validation by CLI syntax kind. *)
let validate kind value =
  match kind with
  | "handle" -> validate_handle value
  | "did" -> validate_did value
  | "nsid" -> validate_nsid value
  | "at-uri" -> validate_at_uri value
  | "rkey" -> validate_rkey value
  | "cid" -> validate_cid value
  | "tid" -> validate_tid value
  | "datetime" -> validate_datetime value
  | "language" -> validate_language value
  | "url" | "service-url" -> validate_service_url value
  | "artifact-path" -> validate_artifact_path value
  | _ -> Invalid ("unknown syntax kind: " ^ kind)
