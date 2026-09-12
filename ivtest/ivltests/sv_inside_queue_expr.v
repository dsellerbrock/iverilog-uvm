// `x inside {expr}' where expr is a QUEUE-valued expression that is
// neither a plain signal nor a class property (e.g. a function call
// result) used to force the membership result to 0 and print
// "vvp.tgt error: unsupported container operand for the inside
// operator" -- tgt-vvp/eval_vec4.c's object-stack dispatch checked
// IVL_VT_DARRAY but not IVL_VT_QUEUE, even though its own comment says
// "Queue/darray held in an expression" and the identical queue as a
// class property already worked (L38). A dynamic-array-returning
// function already worked before this fix (IVL_VT_DARRAY was already
// checked); kept here as a sibling positive control.

module test;
  typedef int int_q_t[$];
  typedef int int_da_t[];

  function automatic int_q_t get_q();
    int_q_t r;
    r.push_back(1);
    r.push_back(2);
    return r;
  endfunction

  function automatic int_da_t get_da();
    int_da_t r;
    r = new[2];
    r[0] = 1;
    r[1] = 2;
    return r;
  endfunction

  int errors;

  initial begin
    errors = 0;

    if (3 inside {get_q()}) begin
      $display("FAILED: 3 should not be inside the queue");
      errors = errors + 1;
    end
    if (!(2 inside {get_q()})) begin
      $display("FAILED: 2 should be inside the queue");
      errors = errors + 1;
    end
    if (!(2 inside {get_da()})) begin
      $display("FAILED: 2 should be inside the dynamic array");
      errors = errors + 1;
    end

    if (errors == 0)
      $display("PASSED");
    else
      $display("FAILED");
  end
endmodule
