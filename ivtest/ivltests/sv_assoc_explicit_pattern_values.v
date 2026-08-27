// IEEE 1800-2017/2023 7.9.11 and 10.9: keyed assignment patterns
// construct associative arrays with explicit entries and, optionally, a
// default value. Explicit entries are real members; a default is fallback
// state and does not create a member.
class assoc_explicit_token;
  int value;

  function new(input int value);
    this.value = value;
  endfunction
endclass

typedef enum logic [1:0] {
  PATTERN_IDLE = 2'b00,
  PATTERN_RUN  = 2'b01,
  PATTERN_STOP = 2'b10
} assoc_pattern_key_e;

typedef int assoc_explicit_int_map_t[string];

module main;
  localparam string NAMED_STRING_KEY = "named";

  int string_key_values[string] =
      '{"alpha":11, "beta":22, default:-1};
  int named_string_key_values[string] =
      '{NAMED_STRING_KEY:33};
  string integral_key_values[int] =
      '{-4:"minus-four", 7:"seven", default:"missing"};
  real enum_key_values[assoc_pattern_key_e] =
      '{PATTERN_IDLE:1.25, PATTERN_RUN:2.50, default:-0.50};

  assoc_explicit_token class_values[string];
  assoc_explicit_token class_copy[string];
  assoc_explicit_int_map_t procedural_values;
  assoc_explicit_int_map_t expression_value;

  bit failed;
  int eval_step;

  task automatic check(input string label, input logic ok);
    if (ok !== 1'b1) begin
      $display("FAILED -- %0s", label);
      failed = 1'b1;
    end
  endtask

  function automatic int ordered_value(input int expected_step,
                                       input int result);
    if (eval_step != expected_step)
      failed = 1'b1;
    eval_step += 1;
    return result;
  endfunction

  function automatic int replace_during_rhs(input int expected_step,
                                             input int result);
    if (eval_step != expected_step)
      failed = 1'b1;
    eval_step += 1;
    // This side effect must happen while the outer RHS is evaluated, then be
    // superseded by the complete outer value. It must not become an entry in
    // the new associative array or mutate a partially installed value.
    procedural_values = '{"rhs-side-effect":901, default:-901};
    return result;
  endfunction

  function automatic assoc_explicit_int_map_t make_map(input int value);
    return '{"made":value, default:value + 1};
  endfunction

  function automatic bit accepts_map(input assoc_explicit_int_map_t value,
                                     input string key,
                                     input int explicit_value,
                                     input int fallback_value);
    bit ok;
    ok = value.size() == 1 && value.exists(key) &&
         value[key] == explicit_value && !value.exists("absent") &&
         value["absent"] == fallback_value;
    value["callee-local"] = 999;
    return ok;
  endfunction

  initial begin
    assoc_explicit_token fallback;
    assoc_explicit_token live;
    bit choose;

    failed = 1'b0;

    // String keys and integral elements.
    check("string-key size", string_key_values.size() == 2);
    check("string-key explicit entries",
          string_key_values.exists("alpha") &&
          string_key_values.exists("beta") &&
          string_key_values["alpha"] == 11 &&
          string_key_values["beta"] == 22);
    check("string-key fallback is not a member",
          !string_key_values.exists("other") &&
          string_key_values["other"] == -1 &&
          string_key_values.size() == 2);
    check("named constant string key",
          named_string_key_values.size() == 1 &&
          named_string_key_values.exists("named") &&
          named_string_key_values["named"] == 33);
    string_key_values.delete("alpha");
    check("delete explicit reveals fallback",
          !string_key_values.exists("alpha") &&
          string_key_values["alpha"] == -1 &&
          string_key_values.size() == 1);

    // Signed integral keys and string elements preserve both key identity and
    // the complete string value.
    check("integral-key size", integral_key_values.size() == 2);
    check("negative integral key",
          integral_key_values.exists(-4) &&
          integral_key_values[-4] == "minus-four");
    check("positive integral key",
          integral_key_values.exists(7) &&
          integral_key_values[7] == "seven");
    check("integral-key string fallback",
          !integral_key_values.exists(99) &&
          integral_key_values[99] == "missing");

    // Enum keys and real elements exercise nominal key conversion and a
    // non-integral element representation.
    check("enum-key size", enum_key_values.size() == 2);
    check("enum-key explicit real values",
          enum_key_values[PATTERN_IDLE] == 1.25 &&
          enum_key_values[PATTERN_RUN] == 2.50);
    check("enum-key real fallback",
          !enum_key_values.exists(PATTERN_STOP) &&
          enum_key_values[PATTERN_STOP] == -0.50);

    // Class elements retain handle identity. Copying the associative array
    // copies its entries and fallback state, but not the objects themselves.
    fallback = new(31);
    live = new(41);
    class_values = '{"live":live, default:fallback};
    check("class explicit handle",
          class_values.size() == 1 &&
          class_values.exists("live") && class_values["live"] == live);
    check("class fallback handle",
          !class_values.exists("absent") &&
          class_values["absent"] == fallback);
    class_copy = class_values;
    class_copy["live"].value = 42;
    fallback.value = 32;
    check("class copy preserves handle identity",
          class_values["live"].value == 42 &&
          class_copy["absent"].value == 32 &&
          class_values["absent"].value == 32);

    // Every value expression is evaluated exactly once, in lexical order,
    // before the destination is replaced. A same-destination side effect in
    // the second expression is therefore visible during evaluation but does
    // not survive the final whole-array assignment.
    procedural_values["old"] = 1000;
    eval_step = 0;
    procedural_values = '{
      "first":ordered_value(0, 101),
      "replace":replace_during_rhs(1, 202),
      default:ordered_value(2, -303),
      "last":ordered_value(3, 404)
    };
    check("explicit RHS lexical evaluation order", eval_step == 4);
    check("procedural replacement is atomic",
          procedural_values.size() == 3 &&
          !procedural_values.exists("old") &&
          !procedural_values.exists("rhs-side-effect") &&
          procedural_values["first"] == 101 &&
          procedural_values["replace"] == 202 &&
          procedural_values["last"] == 404 &&
          procedural_values["absent"] == -303);

    // Assignment patterns are context-determined aggregate expressions in
    // typed patterns, actual arguments, return statements, and conditional
    // arms. Each use constructs a fresh associative-array value.
    expression_value = assoc_explicit_int_map_t'{
      "typed":501, default:502
    };
    check("typed explicit pattern",
          accepts_map(expression_value, "typed", 501, 502));
    check("typed value is copied into input formal",
          !expression_value.exists("callee-local") &&
          expression_value.size() == 1);

    check("explicit pattern actual argument",
          accepts_map('{"actual":503, default:504},
                      "actual", 503, 504));

    expression_value = make_map(505);
    check("explicit pattern function return",
          accepts_map(expression_value, "made", 505, 506));

    choose = 1'b1;
    expression_value = choose ? '{"true":507, default:508}
                              : '{"false":509, default:510};
    check("explicit pattern conditional true arm",
          accepts_map(expression_value, "true", 507, 508));
    choose = 1'b0;
    expression_value = choose ? '{"true":511, default:512}
                              : '{"false":513, default:514};
    check("explicit pattern conditional false arm",
          accepts_map(expression_value, "false", 513, 514));

    if (failed)
      $display("FAILED");
    else
      $display("PASSED");
  end
endmodule
