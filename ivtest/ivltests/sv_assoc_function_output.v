// Pure output associative formals start empty on every call and copy their
// final value back to direct and class-property actuals.
module sv_assoc_function_output;
  typedef int assoc_t[string];
  typedef int wildcard_t[*];

  class Holder;
    assoc_t values;
  endclass

  class Helper;
    function automatic int replace(output assoc_t value);
      replace = value.size();
      value["method"] = 44;
    endfunction

    function automatic int replace_default(output assoc_t value);
      value = '{default:45};
      replace_default = value.size();
    endfunction
  endclass

  assoc_t actual;
  wildcard_t wildcard_actual;
  Holder holder;
  Helper helper;
  int seen;

  function automatic int replace_auto(output assoc_t value);
    replace_auto = value.size();
    value["auto"] = 22;
  endfunction

  function int replace_static(output assoc_t value);
    replace_static = value.size();
    value["static"] = 33;
  endfunction

  function automatic int replace_default(output assoc_t value);
    value = '{default:55};
    replace_default = value.size();
  endfunction

  function automatic int replace_wildcard(output wildcard_t value);
    value = '{default:66};
    replace_wildcard = value.size();
  endfunction

  task automatic replace_task(output assoc_t value,
                               output int initial_size);
    initial_size = value.size();
    value = '{default:77};
  endtask

  task automatic mutate_inout(inout assoc_t value);
    if (value["missing"] != 88)
      $fatal(1, "FAILED -- inout fallback input");
    value["inout"] = 89;
  endtask

  task automatic mutate_ref(ref assoc_t value);
    if (value["missing"] != 90)
      $fatal(1, "FAILED -- ref fallback input");
    value["ref"] = 91;
  endtask

  initial begin
    actual["old"] = 11;
    seen = replace_auto(actual);
    if (seen != 0 || actual.exists("old") || actual["auto"] != 22)
      $fatal(1, "FAILED -- automatic output default/copyback");

    actual["old"] = 12;
    seen = replace_static(actual);
    if (seen != 0 || actual.exists("old") || actual["static"] != 33)
      $fatal(1, "FAILED -- static output first call");
    actual["again"] = 13;
    seen = replace_static(actual);
    if (seen != 0 || actual.exists("again") || actual["static"] != 33)
      $fatal(1, "FAILED -- static output reset");

    actual["old"] = 15;
    seen = replace_default(actual);
    if (seen != 0 || actual.size() != 0 || actual.exists("old") ||
        actual["missing"] != 55)
      $fatal(1, "FAILED -- output fallback-state copyback");

    wildcard_actual[8'h12] = 16;
    seen = replace_wildcard(wildcard_actual);
    if (seen != 0 || wildcard_actual.size() != 0 ||
        wildcard_actual[8'h12] != 66 ||
        wildcard_actual[48'h1234_5678_9abc] != 66)
      $fatal(1, "FAILED -- wildcard output fallback copyback");

    actual["old"] = 17;
    replace_task(actual, seen);
    if (seen != 0 || actual.size() != 0 || actual.exists("old") ||
        actual["missing"] != 77)
      $fatal(1, "FAILED -- task output fallback copyback");

    actual = '{default:88};
    mutate_inout(actual);
    if (actual["missing"] != 88 || actual["inout"] != 89)
      $fatal(1, "FAILED -- task inout fallback copyback");

    actual = '{default:90};
    mutate_ref(actual);
    if (actual["missing"] != 90 || actual["ref"] != 91)
      $fatal(1, "FAILED -- task ref fallback copyback");

    holder = new;
    helper = new;
    holder.values["old"] = 14;
    seen = helper.replace(holder.values);
    if (seen != 0 || holder.values.exists("old") ||
        holder.values["method"] != 44)
      $fatal(1, "FAILED -- method property output copyback");
    holder.values["old"] = 18;
    seen = helper.replace_default(holder.values);
    if (seen != 0 || holder.values.size() != 0 ||
        holder.values.exists("old") || holder.values["missing"] != 45)
      $fatal(1, "FAILED -- method property fallback copyback");

    $display("PASSED");
  end
endmodule
