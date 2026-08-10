// IEEE 1800-2017 7.9.11: a lone associative-array default pattern is a
// context-determined aggregate value. It must remain a fresh map when nested
// in casts, conditional arms, returns, and subroutine actual arguments.
class assoc_context_token;
  int value;

  function new(input int value);
    this.value = value;
  endfunction
endclass

typedef int assoc_int_map_t[string];
typedef assoc_context_token assoc_object_map_t[int];

class assoc_context_holder;
  bit constructor_ok;

  function new(input assoc_int_map_t values);
    constructor_ok = values.size() == 0 &&
                     !values.exists("missing") &&
                     values["missing"] == 61;
    values["constructor-local"] = -1;
  endfunction

  function automatic bit accepts(input assoc_int_map_t values,
                                 input int expected);
    bit ok;
    ok = values.size() == 0 &&
         !values.exists("missing") &&
         values["missing"] == expected;
    values["method-local"] = -1;
    return ok;
  endfunction
endclass

module main;
  bit failed;
  bit choose;
  int eval_count;
  assoc_int_map_t cast_source = '{default:56};
  assoc_int_map_t returned;
  assoc_int_map_t selected;
  assoc_context_token fallback;
  assoc_context_holder object;

  task automatic check(input string label, input logic ok);
    if (ok !== 1'b1) begin
      $display("FAILED -- %0s", label);
      failed = 1'b1;
    end
  endtask

  function automatic int fallback_once(input int result);
    eval_count += 1;
    return result;
  endfunction

  function automatic bit accepts_function(input assoc_int_map_t values,
                                           input int expected);
    bit ok;
    ok = values.size() == 0 &&
         !values.exists("missing") &&
         values["missing"] == expected;
    values["function-local"] = -1;
    return ok;
  endfunction

  function automatic bit accepts_object(
      input assoc_object_map_t values,
      input assoc_context_token expected);
    return values.size() == 0 &&
           !values.exists(99) &&
           values[99] == expected;
  endfunction

  function automatic bit accepts_default(
      input assoc_int_map_t values = '{default:65});
    bit ok;
    ok = values.size() == 0 &&
         !values.exists("missing") &&
         values["missing"] == 65;
    values["default-local"] = -1;
    return ok;
  endfunction

  function automatic assoc_int_map_t make_direct(input int value);
    return '{default:value};
  endfunction

  function automatic assoc_int_map_t make_conditional(input bit select);
    return select ? '{default:71} : '{default:72};
  endfunction

  task accepts_task(input assoc_int_map_t values, input int expected);
    check("task actual", values.size() == 0 &&
          !values.exists("missing") &&
          values["missing"] == expected);
    values["task-local"] = -1;
  endtask

  initial begin
    failed = 1'b0;
    eval_count = 0;

    check("function actual",
          accepts_function('{default:fallback_once(51)}, 51));
    check("fallback evaluated once", eval_count == 1);
    check("fresh function actual first",
          accepts_function('{default:52}, 52));
    check("fresh function actual second",
          accepts_function('{default:52}, 52));

    check("typed actual",
          accepts_function(assoc_int_map_t'{default:53}, 53));
    eval_count = 0;
    check("nested cast actual",
          accepts_function(
              assoc_int_map_t'(
                  assoc_int_map_t'{default:fallback_once(54)}), 54));
    check("nested cast evaluated once", eval_count == 1);

    selected = assoc_int_map_t'(cast_source);
    check("same-type map cast", selected.size() == 0 &&
          !selected.exists("missing") && selected["missing"] == 56);
    selected["local"] = -1;
    check("same-type map cast copies state",
          cast_source.size() == 0 &&
          !cast_source.exists("local") &&
          cast_source["local"] == 56);

    selected = assoc_int_map_t'{};
    check("same-type typed empty", selected.size() == 0 &&
          !selected.exists("missing") && selected["missing"] == 0);

    accepts_task('{default:55}, 55);
    accepts_task('{default:55}, 55);

    object = new('{default:61});
    check("constructor actual", object != null && object.constructor_ok);
    check("method actual first", object.accepts('{default:62}, 62));
    check("method actual second", object.accepts('{default:62}, 62));

    check("default argument first", accepts_default());
    check("default argument second", accepts_default());

    fallback = new(81);
    check("class-handle fallback argument",
          accepts_object('{default:fallback}, fallback));

    returned = make_direct(70);
    check("direct function return", returned.size() == 0 &&
          !returned.exists("missing") && returned["missing"] == 70);
    returned = make_conditional(1'b1);
    check("conditional function return true", returned.size() == 0 &&
          !returned.exists("missing") && returned["missing"] == 71);
    returned = make_conditional(1'b0);
    check("conditional function return false", returned.size() == 0 &&
          !returned.exists("missing") && returned["missing"] == 72);

    // Only the selected conditional arm is evaluated, once, and its marker
    // becomes a fresh empty map carrying fallback state rather than `null`.
    eval_count = 0;
    choose = 1'b1;
    selected = choose ? '{default:fallback_once(73)}
                      : '{default:fallback_once(74)};
    check("ternary true", selected.size() == 0 &&
          !selected.exists("missing") && selected["missing"] == 73);
    check("ternary true evaluated once", eval_count == 1);
    eval_count = 0;
    choose = 1'b0;
    selected = choose ? '{default:fallback_once(73)}
                      : '{default:fallback_once(74)};
    check("ternary false", selected.size() == 0 &&
          !selected.exists("missing") && selected["missing"] == 74);
    check("ternary false evaluated once", eval_count == 1);

    selected = 1'b1 ? '{default:76} : '{default:77};
    check("constant ternary true", selected.size() == 0 &&
          !selected.exists("missing") && selected["missing"] == 76);
    selected = 1'b0 ? '{default:76} : '{default:77};
    check("constant ternary false", selected.size() == 0 &&
          !selected.exists("missing") && selected["missing"] == 77);

    // A context-shaped empty pattern has the same conditional object category
    // as a default marker. Selecting it clears both entries and fallback state.
    choose = 1'b1;
    selected = choose ? '{} : '{default:75};
    check("ternary empty arm", selected.size() == 0 &&
          !selected.exists("missing") && selected["missing"] == 0);
    choose = 1'b0;
    selected = choose ? '{} : '{default:75};
    check("ternary default beside empty", selected.size() == 0 &&
          !selected.exists("missing") && selected["missing"] == 75);

    if (failed)
      $display("FAILED");
    else
      $display("PASSED");
  end
endmodule
