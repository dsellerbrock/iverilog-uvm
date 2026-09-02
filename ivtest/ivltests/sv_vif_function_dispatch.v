// IEEE 1800-2017/2023 25.9 and 13.4.1: a value-returning function call
// through a virtual interface applies to the interface instance currently
// designated by the handle. Rebinding the handle must change the receiver;
// candidate-specific actual/default rows must evaluate only after that
// receiver is selected, nested calls must preserve the outer call state, and
// every scalar/container return category must retain its value across the
// selected function frame.
class vif_function_dispatch_token;
  int origin;

  function new(input int value);
    origin = value;
  endfunction
endclass

typedef int vif_function_dispatch_queue_t[$];
typedef int vif_function_dispatch_darray_t[];

interface vif_function_dispatch_if(input logic pin, input int tag);
  int explicit_calls = 0;
  int static_calls = 0;
  int default_calls = 0;
  int static_default_calls = 0;
  int real_calls = 0;
  int string_calls = 0;
  int object_calls = 0;
  int queue_calls = 0;
  int darray_calls = 0;
  int wide_calls = 0;

  function automatic logic sample();
    return pin;
  endfunction

  function automatic int consume_explicit(input int value);
    explicit_calls += 1;
    return tag * 100 + value;
  endfunction

  // Deliberately static (the default for an interface function). The inner
  // same-method call is the actual for the outer call, so dispatch/argument
  // state for the outer call must survive the nested invocation.
  function int static_fold(input int value);
    static_calls += 1;
    return tag * 10 + value;
  endfunction

  // IEEE 1800-2017/2023 13.5.3: an omitted argument may depend on an earlier
  // formal. The interface member additionally makes the default specific to
  // the selected concrete instance.
  function automatic int selected_default(
      input int first, input int second = first + tag);
    default_calls += 1;
    return tag * 100 + second;
  endfunction

  // The same default rule applies to a static function. Argument lowering
  // must expose first while evaluating second, then restore both formals if a
  // nested call overwrote the shared static storage.
  function int selected_static_default(
      input int first, input int second = first + tag);
    static_default_calls += 1;
    return tag * 1000 + second;
  endfunction

  function automatic real selected_real(input real bias);
    real_calls += 1;
    return tag + bias;
  endfunction

  function automatic string selected_string();
    string_calls += 1;
    if (tag == 7)
      return "selected-7";
    return "other";
  endfunction

  function automatic vif_function_dispatch_token selected_object();
    vif_function_dispatch_token result;
    result = new(tag);
    object_calls += 1;
    return result;
  endfunction

  function automatic vif_function_dispatch_queue_t selected_queue();
    vif_function_dispatch_queue_t result;
    result.push_back(tag);
    result.push_back(tag + 1);
    queue_calls += 1;
    return result;
  endfunction

  function automatic vif_function_dispatch_darray_t selected_darray();
    vif_function_dispatch_darray_t result;
    result = new[2];
    result[0] = tag;
    result[1] = tag + 1;
    darray_calls += 1;
    return result;
  endfunction

  function automatic logic [79:0] selected_wide();
    wide_calls += 1;
    return {40'h123456789a, tag, 8'ha5};
  endfunction
endinterface

module sv_vif_function_dispatch;
  logic a = 1'b0;
  logic b = 1'b1;
  int tag0 = 2;
  int tag1 = 7;
  int actual_evaluations = 0;
  int result;
  real real_result;
  string string_result;
  vif_function_dispatch_token object_result;
  vif_function_dispatch_queue_t queue_result;
  vif_function_dispatch_darray_t darray_result;
  logic [79:0] wide_result;
  vif_function_dispatch_if p0(a, tag0);
  vif_function_dispatch_if p1(b, tag1);
  virtual vif_function_dispatch_if vif;

  function automatic int side_effecting_actual();
    actual_evaluations += 1;
    return 5;
  endfunction

  initial begin
    vif = p0;
    #1;
    if (vif.sample() !== 1'b0)
      $fatal(1, "first VIF receiver misdispatched");

    vif = p1;
    if (vif.sample() !== 1'b1)
      $fatal(1, "rebound VIF receiver misdispatched");

    a = 1'b1;
    b = 1'b0;
    #1;
    if (vif.sample() !== 1'b0)
      $fatal(1, "rebound VIF did not observe selected instance");

    // Both p0 and p1 contribute compatible candidate rows. Only p1's row may
    // evaluate this explicit actual, and the source expression runs once.
    result = vif.consume_explicit(.value(side_effecting_actual()));
    if (result != 705 || actual_evaluations != 1)
      $fatal(1, "explicit VIF actual was duplicated or misdispatched");
    if (p0.explicit_calls != 0 || p1.explicit_calls != 1)
      $fatal(1, "unselected explicit-argument candidate executed");

    result = vif.static_fold(vif.static_fold(3));
    if (result != 143)
      $fatal(1, "nested static VIF function call corrupted outer call");
    if (p0.static_calls != 0 || p1.static_calls != 2)
      $fatal(1, "nested static VIF function used the wrong instance");

    result = vif.selected_default(5);
    if (result != 712)
      $fatal(1, "VIF default missed earlier formal or selected state");
    if (p0.default_calls != 0 || p1.default_calls != 1)
      $fatal(1, "automatic VIF default used an unselected instance");

    result = vif.selected_static_default(5);
    if (result != 7012)
      $fatal(1, "static VIF default missed the current earlier formal");
    if (p0.static_default_calls != 0 || p1.static_default_calls != 1)
      $fatal(1, "static VIF default used an unselected instance");

    real_result = vif.selected_real(0.5);
    string_result = vif.selected_string();
    object_result = vif.selected_object();
    queue_result = vif.selected_queue();
    darray_result = vif.selected_darray();
    wide_result = vif.selected_wide();
    if (real_result != 7.5)
      $fatal(1, "real VIF function result was corrupted");
    if (string_result != "selected-7")
      $fatal(1, "string VIF function result was corrupted");
    if (object_result == null || object_result.origin != 7)
      $fatal(1, "class VIF function result lost identity");
    if (queue_result.size() != 2 || queue_result[0] != 7 ||
        queue_result[1] != 8)
      $fatal(1, "queue VIF function result was corrupted");
    if (darray_result.size() != 2 || darray_result[0] != 7 ||
        darray_result[1] != 8)
      $fatal(1, "dynamic-array VIF function result was corrupted");
    if (wide_result !== 80'h123456789a_00000007_a5)
      $fatal(1, "wide packed VIF function result was corrupted");
    if (p0.real_calls != 0 || p0.string_calls != 0 ||
        p0.object_calls != 0 || p0.queue_calls != 0 ||
        p0.darray_calls != 0 || p0.wide_calls != 0)
      $fatal(1, "an unselected typed-return candidate executed");
    if (p1.real_calls != 1 || p1.string_calls != 1 ||
        p1.object_calls != 1 || p1.queue_calls != 1 ||
        p1.darray_calls != 1 || p1.wide_calls != 1)
      $fatal(1, "the selected typed-return candidate did not execute once");

    $display("PASSED");
  end
endmodule
