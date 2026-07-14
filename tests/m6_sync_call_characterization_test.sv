// M6 item 5 characterization suite: synchronous function/task call
// semantics (IEEE 1800-2017 13.4 functions, 13.5 tasks, 13.4.2 return,
// 8.10/8.11 class method calls).
//
// vvp today executes a called function/task thread SYNCHRONOUSLY inside
// the caller's opcode dispatch (%callf -> do_callf_void), rather than
// suspending the caller and scheduling the callee as a normal thread.
// That model carries the scheduler audit's highest-risk heuristics
// (staged-context, synchronous drain budgets, UVM-identifier limits).
// Item 5 will replace it with an explicit scheduled-call protocol.
//
// These checks pin the observable invariants that ANY such protocol
// must preserve.  They characterize CURRENT correct behavior and must
// stay green through the restructuring; a regression here means the
// protocol replacement changed call semantics.
module m6_sync_call_characterization_test;
  int errors = 0;

  task check(string what, int got, int exp);
    if (got !== exp) begin
      $display("FAIL %s: got %0d expect %0d", what, got, exp);
      errors++;
    end
  endtask

  // --- 1. plain function returns a value to the caller -----------------
  function automatic int add1(int x); return x + 1; endfunction

  // --- 2. recursion: the callee is a fresh frame each call -------------
  function automatic int fact(int n);
    if (n <= 1) return 1;
    return n * fact(n - 1);
  endfunction

  // --- 3. function calling function (synchronous chain) ----------------
  function automatic int dbl(int x); return x * 2; endfunction
  function automatic int quad(int x); return dbl(dbl(x)); endfunction

  // --- 4. output / ref arguments write back before the caller resumes --
  task automatic add_and_double(input int a, input int b,
                                output int sum, ref int acc);
    sum = a + b;
    acc = acc + sum;
  endtask

  // --- 5. void function used for its side effect -----------------------
  int side;
  function automatic void bump(int by); side += by; endfunction

  // --- 6. class method calls, chained builder pattern ------------------
  class Box;
    int v;
    function automatic Box set(int nv); v = nv; return this; endfunction
    function automatic int get(); return v; endfunction
  endclass

  // --- 7. function that consumes an automatic local across recursion ---
  function automatic int sum_to(int n);
    int local_acc;      // fresh per frame
    local_acc = n;
    if (n == 0) return 0;
    return local_acc + sum_to(n - 1);
  endfunction

  int o1, acc;
  Box b;
  int r;

  initial begin
    // 1
    check("add1", add1(41), 42);
    // 2
    check("fact5", fact(5), 120);
    // 3
    check("quad3", quad(3), 12);         // dbl(dbl(3)) = 12
    // 4
    acc = 100;
    add_and_double(3, 4, o1, acc);
    check("out sum", o1, 7);
    check("ref acc", acc, 107);
    // 5
    side = 0;
    bump(5); bump(7);
    check("void side effect", side, 12);
    // 6 chained method calls on a returned handle
    b = new();
    r = b.set(9).get();                  // set returns this, then get
    check("builder chain", r, 9);
    check("builder state", b.v, 9);
    // 7
    check("sum_to 10", sum_to(10), 55);

    // 8. function call in a condition / expression context
    if (add1(9) == 10) check("expr-ctx", 1, 1);
    else check("expr-ctx", 0, 1);

    // 9. moderately deep recursion completes synchronously (no delay)
    check("fact10", fact(10), 3628800);

    // 10. a call inside a fork/join_none child still returns synchronously
    fork
      begin
        int fr;
        fr = quad(5);                    // 20
        check("fork call", fr, 20);
      end
    join

    if (errors == 0) $display("PASS");
    else $display("%0d checks failed", errors);
    $finish;
  end
endmodule
