// IEEE 1800-2017/2023 7.10.3 and 13.5.2: forwarding a queue element
// selected through a ref queue formal retains the selected element's identity.
module main;
  int ref_q[$];
  int const_q[$];
  int direct_q[$];
  int errors = 0;

  task automatic read_expected(const ref int value);
    #2;
    if (value !== 22) begin
      $display("FAILED: ref read got %0d want 22", value);
      errors += 1;
    end
  endtask

  task automatic forward_ref(ref int values[$]);
    read_expected(values[1]);
  endtask

  task automatic forward_const_ref(const ref int values[$]);
    read_expected(values[1]);
  endtask

  initial begin
    ref_q = '{1, 2, 3};
    const_q = '{1, 2, 3};
    direct_q = '{1, 2, 3};

    fork
      forward_ref(ref_q);
      forward_const_ref(const_q);
      read_expected(direct_q[1]);
    join_none

    #1;
    ref_q.push_front(0);
    ref_q[2] = 22;
    const_q.push_front(0);
    const_q[2] = 22;
    direct_q.push_front(0);
    direct_q[2] = 22;
    #2;

    if (errors == 0)
      $display("PASSED");
    else
      $display("FAILED with %0d error(s)", errors);
  end
endmodule
