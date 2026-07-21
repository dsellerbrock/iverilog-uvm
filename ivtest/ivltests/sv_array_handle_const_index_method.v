// A method call on a constant-indexed element of a static unpacked array of
// class handles (arr[0].method()) crashed the compiler: the receiver index
// was elaborated and then handed to the variable-index normalization path,
// which asserts that at least one index is non-constant, so a folded
// constant index aborted ivl (netmisc.cc canonical_expr assertion). The
// constant-index path is now used when the element index folds to a
// constant. Variable indices and queues were unaffected.
module sv_array_handle_const_index_method;
  class Box;
    int val;
    function int  get();        return val; endfunction
    function void set(int v);   val = v;    endfunction
  endclass

  Box qa[3];
  int errors = 0;

  initial begin
    // set() is a void method called as a STATEMENT with a constant index
    // (the task-method path), which had the same crash as the function-
    // expression path below.
    qa[0] = new; qa[0].set(-5);
    for (int i = 1; i < 3; i++) begin qa[i] = new; qa[i].set(i*10 - 5); end

    // Constant-index method calls (the crash case) address the right element.
    if (qa[0].get() != -5) begin $display("FAIL qa[0]=%0d", qa[0].get()); errors++; end
    if (qa[1].get() !=  5) begin $display("FAIL qa[1]=%0d", qa[1].get()); errors++; end
    if (qa[2].get() != 15) begin $display("FAIL qa[2]=%0d", qa[2].get()); errors++; end

    // Variable index still works and agrees.
    for (int k = 0; k < 3; k++)
      if (qa[k].get() != k*10 - 5) begin $display("FAIL var qa[%0d]", k); errors++; end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
  end
endmodule
