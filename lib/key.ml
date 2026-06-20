(** Read-only atproto multikey inspection. *)

type kind = P256_public | P256_private | K256_public | K256_private

type inspected = {
  kind : kind;
  encoding : [ `Multibase | `Did_key ];
  multibase : string;
  did_key : string option;
}

type generated = {
  kind : kind;
  secret_multibase : string;
  public_did_key : string;
}

type curve = {
  p : Z.t;
  a : Z.t;
  b : Z.t;
  n : Z.t;
  gx : Z.t;
  gy : Z.t;
  public_prefix : string;
  private_prefix : string;
}

type point = Infinity | Point of Z.t * Z.t

let alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

let alphabet_index =
  let table = Array.make 128 (-1) in
  String.iteri
    (fun index char ->
      let code = Char.code char in
      if code < Array.length table then table.(code) <- index)
    alphabet;
  table

let base58_decode value =
  let base = Z.of_int 58 in
  let rec loop index acc =
    if index = String.length value then Ok acc
    else
      let code = Char.code value.[index] in
      if code >= Array.length alphabet_index || alphabet_index.(code) < 0 then
        Error "not a multibase base58btc string"
      else loop (index + 1) Z.((acc * base) + of_int alphabet_index.(code))
  in
  let leading_zeroes =
    let rec loop index =
      if index < String.length value && value.[index] = '1' then loop (index + 1)
      else index
    in
    loop 0
  in
  match loop 0 Z.zero with
  | Error _ as error -> error
  | Ok number ->
      let hex = Z.format "%x" number in
      let hex = if String.length hex mod 2 = 0 then hex else "0" ^ hex in
      let bytes =
        if number = Z.zero then ""
        else
          let len = String.length hex / 2 in
          String.init len (fun index ->
              int_of_string ("0x" ^ String.sub hex (index * 2) 2) |> Char.chr)
      in
      Ok (String.make leading_zeroes '\000' ^ bytes)

let base58_encode bytes =
  let base = Z.of_int 58 in
  let number =
    String.fold_left
      (fun acc char -> Z.((acc * of_int 256) + of_int (Char.code char)))
      Z.zero bytes
  in
  let rec encode number acc =
    if number = Z.zero then acc
    else
      let q, r = Z.ediv_rem number base in
      encode q (String.make 1 alphabet.[Z.to_int r] ^ acc)
  in
  let leading_zeroes =
    let rec loop index =
      if index < String.length bytes && bytes.[index] = '\000' then
        loop (index + 1)
      else index
    in
    loop 0
  in
  String.make leading_zeroes '1'
  ^ if number = Z.zero then "" else encode number ""

let multibase_of_payload payload = "z" ^ base58_encode payload
let did_key_of_multibase multibase = "did:key:" ^ multibase
let z_of_hex value = Z.of_string_base 16 value

let p256 =
  {
    p =
      z_of_hex
        "ffffffff00000001000000000000000000000000ffffffffffffffffffffffff";
    a =
      z_of_hex
        "ffffffff00000001000000000000000000000000fffffffffffffffffffffffc";
    b =
      z_of_hex
        "5ac635d8aa3a93e7b3ebbd55769886bc651d06b0cc53b0f63bce3c3e27d2604b";
    n =
      z_of_hex
        "ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551";
    gx =
      z_of_hex
        "6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296";
    gy =
      z_of_hex
        "4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5";
    public_prefix = "\x80\x24";
    private_prefix = "\x86\x26";
  }

let k256 =
  {
    p =
      z_of_hex
        "fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f";
    a = Z.zero;
    b = Z.of_int 7;
    n =
      z_of_hex
        "fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141";
    gx =
      z_of_hex
        "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798";
    gy =
      z_of_hex
        "483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8";
    public_prefix = "\xe7\x01";
    private_prefix = "\x81\x26";
  }

let mod_curve curve value =
  Z.erem (Z.add (Z.erem value curve.p) curve.p) curve.p

let point_add curve left right =
  match (left, right) with
  | Infinity, point | point, Infinity -> point
  | Point (x1, y1), Point (x2, y2) ->
      if Z.equal x1 x2 && Z.equal (mod_curve curve Z.(y1 + y2)) Z.zero then
        Infinity
      else
        let slope =
          if Z.equal x1 x2 && Z.equal y1 y2 then
            let numerator = Z.((of_int 3 * x1 * x1) + curve.a) in
            let denominator = Z.(of_int 2 * y1) in
            mod_curve curve
              Z.(numerator * invert (mod_curve curve denominator) curve.p)
          else
            let numerator = Z.(y2 - y1) in
            let denominator = Z.(x2 - x1) in
            mod_curve curve
              Z.(numerator * invert (mod_curve curve denominator) curve.p)
        in
        let x3 = mod_curve curve Z.((slope * slope) - x1 - x2) in
        let y3 = mod_curve curve Z.((slope * (x1 - x3)) - y1) in
        Point (x3, y3)

let scalar_mult curve scalar =
  let rec loop scalar addend acc =
    if Z.equal scalar Z.zero then acc
    else
      let acc =
        if Z.testbit scalar 0 then point_add curve acc addend else acc
      in
      loop (Z.shift_right scalar 1) (point_add curve addend addend) acc
  in
  loop scalar (Point (curve.gx, curve.gy)) Infinity

let z_of_bytes bytes =
  String.fold_left
    (fun acc char -> Z.((acc * of_int 256) + of_int (Char.code char)))
    Z.zero bytes

let z_to_32_bytes value =
  let hex = Z.format "%x" value in
  let hex = if String.length hex mod 2 = 0 then hex else "0" ^ hex in
  let bytes =
    if Z.equal value Z.zero then ""
    else
      let len = String.length hex / 2 in
      String.init len (fun index ->
          int_of_string ("0x" ^ String.sub hex (index * 2) 2) |> Char.chr)
  in
  String.make (32 - String.length bytes) '\000' ^ bytes

let derive_public_multibase curve private_bytes =
  let scalar = z_of_bytes private_bytes in
  if Z.leq scalar Z.zero || Z.geq scalar curve.n then None
  else
    match scalar_mult curve scalar with
    | Infinity -> None
    | Point (x, y) ->
        let prefix = if Z.is_even y then "\x02" else "\x03" in
        Some
          (multibase_of_payload
             (curve.public_prefix ^ prefix ^ z_to_32_bytes x))

let kind_type = function
  | P256_public -> "P-256 / secp256r1 / ES256 public key"
  | P256_private -> "P-256 / secp256r1 / ES256 private key"
  | K256_public -> "K-256 / secp256k1 / ES256K public key"
  | K256_private -> "K-256 / secp256k1 / ES256K private key"

let rng_initialized = ref false

let ensure_rng () =
  if not !rng_initialized then (
    Mirage_crypto_rng_unix.use_default ();
    rng_initialized := true)

let random_private_bytes curve =
  ensure_rng ();
  let rec loop () =
    let bytes = Mirage_crypto_rng.generate 32 in
    let scalar = z_of_bytes bytes in
    if Z.gt scalar Z.zero && Z.lt scalar curve.n then bytes else loop ()
  in
  loop ()

let generate kind =
  let curve, private_kind =
    match kind with
    | P256_private | P256_public -> (p256, P256_private)
    | K256_private | K256_public -> (k256, K256_private)
  in
  let private_bytes = random_private_bytes curve in
  let secret_multibase =
    multibase_of_payload (curve.private_prefix ^ private_bytes)
  in
  match derive_public_multibase curve private_bytes with
  | None -> Error "failed to derive public key"
  | Some public_multibase ->
      Ok
        {
          kind = private_kind;
          secret_multibase;
          public_did_key = did_key_of_multibase public_multibase;
        }

let parse_multibase value =
  if String.length value < 2 || value.[0] <> 'z' then
    Error "not a multibase base58btc string"
  else
    match base58_decode (String.sub value 1 (String.length value - 1)) with
    | Error reason -> Error reason
    | Ok data ->
        let data_len = String.length data in
        if data_len < 3 then Error "multibase key was too short"
        else
          let prefix a b = Char.code data.[0] = a && Char.code data.[1] = b in
          let payload = String.sub data 2 (data_len - 2) in
          let compressed_public =
            String.length payload = 33
            && (payload.[0] = Char.chr 0x02 || payload.[0] = Char.chr 0x03)
          in
          if prefix 0x80 0x24 && compressed_public then Ok (P256_public, payload)
          else if prefix 0x86 0x26 && String.length payload = 32 then
            Ok (P256_private, payload)
          else if prefix 0xe7 0x01 && compressed_public then
            Ok (K256_public, payload)
          else if prefix 0x81 0x26 && String.length payload = 32 then
            Ok (K256_private, payload)
          else Error "unsupported atproto key type or invalid key length"

let inspect value =
  let encoding, multibase =
    if String.starts_with ~prefix:"did:key:" value then
      (`Did_key, String.sub value 8 (String.length value - 8))
    else (`Multibase, value)
  in
  match parse_multibase multibase with
  | Error reason -> Error reason
  | Ok ((P256_private | K256_private), _) when encoding = `Did_key ->
      Error "DID key encoding only supports public keys"
  | Ok (kind, payload) ->
      let did_key =
        match kind with
        | P256_public | K256_public -> Some (did_key_of_multibase multibase)
        | P256_private ->
            Option.map did_key_of_multibase
              (derive_public_multibase p256 payload)
        | K256_private ->
            Option.map did_key_of_multibase
              (derive_public_multibase k256 payload)
      in
      Ok { kind; encoding; multibase; did_key }
