# deep-diff.jq
#
# Generic recursive diff between two JSON objects, with array-aware
# normalization (arrays of objects are keyed by an identifying field
# such as "name" or "id" instead of positional index), so reordering
# does not produce false positives.
#
# Inputs (via --argjson):
#   $base        - baseline (expected) JSON object
#   $curr        - current (actual) JSON object
#   $array_keys  - list of candidate key field names, e.g. ["name","id","key"]
#   $ignore      - list of regex patterns matched against the dotted path
#
# Output: array of {path, status, baseline, current}
#   status: "added" | "removed" | "changed"

def normalize:
  walk(
    if type == "array" then
      ( . ) as $arr
      | ( [ $array_keys[] as $kf
            | select(($arr | length) > 0 and ($arr[0] | type) == "object" and ($arr[0] | has($kf)))
            | $kf
          ] | first ) as $usekey
      | if $usekey == null then
          $arr
        else
          ( $arr | map({ (.[$usekey] | tostring): . }) | add ) // {}
        end
    else
      .
    end
  );

# NOTE: deliberately not using the builtin `scalars` filter here.
# `paths(scalars)` has a well-known jq gotcha: `scalars` emits the value
# itself (not a boolean), so a leaf whose value is `false` gets dropped by
# the implicit `select()` inside `paths/1`. Using an explicit boolean
# predicate avoids silently losing `false`-valued properties (e.g.
# httpsOnly: false, alwaysOn: false).
def is_leaf: (type as $t | $t != "array" and $t != "object");

def leafpaths_with_values:
  . as $root
  | [ paths(is_leaf) as $p | { path: $p, value: ($root | getpath($p)) } ];

def joinpath:
  map(if type == "number" then "[\(.)]" else tostring end) | join(".") | gsub("\\.\\["; "[");

def is_ignored($p):
  any($ignore[]; . as $pat | $p | test($pat));

( $base | normalize ) as $b
| ( $curr | normalize ) as $c
| ( $b | leafpaths_with_values ) as $bl
| ( $c | leafpaths_with_values ) as $cl
| ( $bl | map({ (.path | joinpath): .value }) | add // {} ) as $bmap
| ( $cl | map({ (.path | joinpath): .value }) | add // {} ) as $cmap
| ( ($bmap | keys) + ($cmap | keys) | unique ) as $allpaths
| [
    $allpaths[] as $p
    | select(is_ignored($p) | not)
    | ( $bmap[$p] ) as $bv
    | ( $cmap[$p] ) as $cv
    | select($bv != $cv)
    | {
        path: $p,
        status: (
          if ($bmap | has($p) | not) then "added"
          elif ($cmap | has($p) | not) then "removed"
          else "changed"
          end
        ),
        baseline: $bv,
        current: $cv
      }
  ]
