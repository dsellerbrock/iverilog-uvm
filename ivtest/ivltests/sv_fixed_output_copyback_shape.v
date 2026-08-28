// IEEE 1800-2017/2023 7.6, 7.7 and 13.5: copying a dynamic array or
// queue back into a fixed-size task/function actual requires an exact size
// match. A run-time mismatch is an error and performs no writes. Exact-size
// controls pin left-to-right copyback for ascending and descending actuals.
module main;
  typedef struct {
    int bad_task[5:3];
    int bad_function[5:3];
    int good_ascending[3:5];
    int good_descending[5:3];
  } payload_t;

  payload_t payload;
  int direct_bad[5:3];
  int direct_bad_long[5:3];
  int direct_bad_queue[5:3];
  int direct_bad_queue_long[5:3];
  int direct_ascending[3:5];
  int direct_descending[5:3];
  int direct_queue[5:3];
  int function_result;
  int failures;

  task automatic check(string what, bit condition);
    if (!condition) begin
      failures++;
      $display("FAILED -- %s", what);
    end
  endtask

  task automatic short_darray(output int value[]);
    value = new[2];
    value[0] = 901;
    value[1] = 902;
  endtask

  task automatic long_darray(output int value[]);
    value = new[4];
    value[0] = 921;
    value[1] = 922;
    value[2] = 923;
    value[3] = 924;
  endtask

  function automatic int short_queue(output int value[$]);
    value.push_back(911);
    value.push_back(912);
    return value.size();
  endfunction

  function automatic int long_queue(output int value[$]);
    value.push_back(931);
    value.push_back(932);
    value.push_back(933);
    value.push_back(934);
    return value.size();
  endfunction

  function automatic int short_darray_function(output int value[]);
    value = new[2];
    value[0] = 913;
    value[1] = 914;
    return value.size();
  endfunction

  task automatic exact_darray(output int value[]);
    value = new[3];
    value[0] = 101;
    value[1] = 102;
    value[2] = 103;
  endtask

  function automatic int exact_queue(output int value[$]);
    value.push_back(111);
    value.push_back(112);
    value.push_back(113);
    return value.size();
  endfunction

  function automatic int exact_darray_function(output int value[]);
    value = new[3];
    value[0] = 121;
    value[1] = 122;
    value[2] = 123;
    return value.size();
  endfunction

  initial begin
    direct_bad[5] = 205;
    direct_bad[4] = 204;
    direct_bad[3] = 203;
    short_darray(direct_bad);
    check("descending direct mismatch is atomic",
          direct_bad[5] == 205 && direct_bad[4] == 204
          && direct_bad[3] == 203);

    direct_bad_long[5] = 215;
    direct_bad_long[4] = 214;
    direct_bad_long[3] = 213;
    long_darray(direct_bad_long);
    check("oversized descending direct mismatch is atomic",
          direct_bad_long[5] == 215 && direct_bad_long[4] == 214
          && direct_bad_long[3] == 213);

    payload.bad_task[5] = 305;
    payload.bad_task[4] = 304;
    payload.bad_task[3] = 303;
    short_darray(payload.bad_task);
    check("task property mismatch is atomic",
          payload.bad_task[5] == 305 && payload.bad_task[4] == 304
          && payload.bad_task[3] == 303);

    payload.bad_function[5] = 405;
    payload.bad_function[4] = 404;
    payload.bad_function[3] = 403;
    function_result = short_darray_function(payload.bad_function);
    check("function property mismatch is atomic",
          function_result == 2
          && payload.bad_function[5] == 405
          && payload.bad_function[4] == 404
          && payload.bad_function[3] == 403);

    direct_bad_queue[5] = 455;
    direct_bad_queue[4] = 454;
    direct_bad_queue[3] = 453;
    function_result = short_queue(direct_bad_queue);
    check("function queue mismatch is atomic",
          function_result == 2
          && direct_bad_queue[5] == 455
          && direct_bad_queue[4] == 454
          && direct_bad_queue[3] == 453);

    direct_bad_queue_long[5] = 465;
    direct_bad_queue_long[4] = 464;
    direct_bad_queue_long[3] = 463;
    function_result = long_queue(direct_bad_queue_long);
    check("oversized function queue mismatch is atomic",
          function_result == 4
          && direct_bad_queue_long[5] == 465
          && direct_bad_queue_long[4] == 464
          && direct_bad_queue_long[3] == 463);

    exact_darray(direct_ascending);
    check("exact ascending direct copyback",
          direct_ascending[3] == 101 && direct_ascending[4] == 102
          && direct_ascending[5] == 103);

    exact_darray(direct_descending);
    check("exact descending direct copyback",
          direct_descending[5] == 101 && direct_descending[4] == 102
          && direct_descending[3] == 103);

    exact_darray(payload.good_ascending);
    check("exact ascending property copyback",
          payload.good_ascending[3] == 101
          && payload.good_ascending[4] == 102
          && payload.good_ascending[5] == 103);

    function_result = exact_darray_function(payload.good_descending);
    check("exact descending property function copyback",
          function_result == 3 && payload.good_descending[5] == 121
          && payload.good_descending[4] == 122
          && payload.good_descending[3] == 123);

    function_result = exact_queue(direct_queue);
    check("exact descending queue function copyback",
          function_result == 3 && direct_queue[5] == 111
          && direct_queue[4] == 112 && direct_queue[3] == 113);

    if (failures == 0) $display("PASSED");
    $finish(0);
  end
endmodule
