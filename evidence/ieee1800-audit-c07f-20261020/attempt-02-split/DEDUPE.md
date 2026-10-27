# Open and closed issue dedupe

Queries and matching issues are listed in [`attempt-01-query/DEDUPE.md`](../attempt-01-query/DEDUPE.md). Additional open+closed searches:

| Search | Open | Closed | Review |
|---|---|---|---|
| `constant expression size` | #611, #652, #754 | none | #611 is a class-scoped type parameter cast; #652 is `$bits` of a dynamic queue; #754 is `type()` as a cast type. None concerns constant array-query expressions. |
| `size Ram` | #792 | none | #792's type-argument queries and standard `Ram` values were reviewed below. |
| `constant array query` | none | none | — |
| `string associative query` | none | none | — |
| `string index query` | none | none | — |
| `nonintegral associative query` | none | none | — |

The three relevant open issues' scope is reviewed below.

## #792 — data-type argument values

The issue tests query functions when the first argument is a data type (for example `$size(Word)`, `$left(int)`, `$dimensions(Word)`) and the required values. It also tests that a dynamically sized type identifier is an error. Its variable-array `Ram` controls invoke `$size(Ram,2)` at run time; the current probes additionally isolate its use as a constant expression.

Scope text from the issue: “The values listed above, and an error for the dynamically sized type identifier.” The standard paragraph cited by the issue also includes fixed-size array query calls in constant expressions; q4b specifically checks that separate expression form.

Reviewed the full body. The reported failed probes are data-type arguments; the `Ram` controls test run-time values and pass. No existing constant-expression `localparam $size(Ram,2)` reproducer is listed.

## #793 — integral-key associative-array query values

The issue covers wrong `$low`, `$high`, `$right`, `$increment`, and `$size` results for associative arrays with integral indices, plus empty-array `$low`/`$high`. It does not test rejection of query functions on a nonintegral index type such as `string`.

Scope text from the issue: “The values in parentheses.” Its probe declarations use `int aa[int]`, so n1's nonintegral key type is outside the reproduced behavior.

## #794 — queries on arrays with variable dimensions

The issue reproduces the standard `int a[3][][5]` example: legal queries of the outer fixed dimension, an indexed dynamic dimension, and the innermost fixed dimension currently fail at runtime, while the invalid dimension-2 query produces the same runtime errors. The current q5 probe rechecks the legal queries; n2 checks the prescribed error for `$size(a,2)`.

Scope text from the issue: “3, 3 and 5 for the three legal queries and an error only for `$size(a,2)`.” q5 reproduces the legal-query failures; n2 reports the expected error for the illegal query.

No issue body was edited. Any matching result will be commented on the existing issue; distinct rules (including n1 or constant-expression context) are candidates for a new issue only after lead classification.
