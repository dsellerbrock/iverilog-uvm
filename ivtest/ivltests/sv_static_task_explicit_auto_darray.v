// IEEE 1800-2023 6.21 and 13.3.1: a declaration explicitly marked
// automatic inside an otherwise static subroutine has per-invocation lifetime.
// The subroutine's ordinary local declarations remain shared static storage.
module sv_static_task_explicit_auto_darray;
  int ready;
  int observed [1:2];
  int recursive_code;
  int zero_calls;
  int void_calls;

  task static overlap(input int id);
    automatic int captured = id;
    automatic int payload[];
    int shared;

    payload = new[2];
    payload[0] = captured;
    payload[1] = captured + 10;
    shared = captured;

    if (captured == 1) begin
      ready = 1;
      #10;
    end else begin
      #1;
    end

    // captured and payload select this invocation. shared deliberately
    // observes the second invocation's write because it remains static.
    observed[captured] = payload[0] * 100 + payload[1] * 10 + shared;
  endtask

  task static zero_formal;
    automatic int payload[];

    payload = new[1];
    payload[0] = zero_calls + 1;
    zero_calls = payload[0];
  endtask

  task automatic automatic_boundary(output int value);
    static int initialized_once = 40;

    initialized_once++;
    value = initialized_once;
  endtask

  function automatic int automatic_function_boundary();
    static int initialized_once = 60;

    initialized_once++;
    return initialized_once;
  endfunction

  function static int function_recurse(input int depth);
    automatic int captured = depth;
    automatic int payload[];
    int nested;

    payload = new[1];
    payload[0] = captured;
    if (captured > 0)
      nested = function_recurse(captured - 1);
    else
      nested = 0;
    return nested * 10 + payload[0];
  endfunction

  function static void void_function();
    automatic int payload[];

    payload = new[1];
    payload[0] = void_calls + 1;
    void_calls = payload[0];
  endfunction

  task static recurse(input int depth);
    automatic int captured = depth;
    automatic int payload[];

    payload = new[1];
    payload[0] = captured;
    if (captured > 0)
      recurse(captured - 1);
    recursive_code = recursive_code * 10 + payload[0];
  endtask

  initial begin
    int first_boundary;
    int second_boundary;

    fork
      overlap(1);
      begin
        wait (ready == 1);
        overlap(2);
      end
    join

    if (observed[1] !== 212 || observed[2] !== 322) begin
      $display("FAILED overlap observed=%0d,%0d", observed[1], observed[2]);
      $finish;
    end

    recursive_code = 0;
    recurse(3);
    if (recursive_code !== 123) begin
      $display("FAILED recurse-3 code=%0d", recursive_code);
      $finish;
    end

    recursive_code = 0;
    recurse(2);
    if (recursive_code !== 12) begin
      $display("FAILED recurse-2 code=%0d", recursive_code);
      $finish;
    end

    zero_formal();
    zero_formal();
    if (zero_calls !== 2) begin
      $display("FAILED zero-formal calls=%0d", zero_calls);
      $finish;
    end

    automatic_boundary(first_boundary);
    automatic_boundary(second_boundary);
    if (first_boundary !== 41 || second_boundary !== 42) begin
      $display("FAILED automatic-static boundary=%0d,%0d",
               first_boundary, second_boundary);
      $finish;
    end

    if (automatic_function_boundary() !== 61 ||
        automatic_function_boundary() !== 62) begin
      $display("FAILED automatic-function-static boundary");
      $finish;
    end

    if (function_recurse(3) !== 123 || function_recurse(2) !== 12) begin
      $display("FAILED static-function explicit-auto frame");
      $finish;
    end

    void_function();
    void_function();
    if (void_calls !== 2) begin
      $display("FAILED static-void-function calls=%0d", void_calls);
      $finish;
    end

    $display("PASSED");
  end
endmodule
