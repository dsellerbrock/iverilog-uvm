module issue2791_inside_queue_x_left;
  logic [3:0] q[$];
  logic [3:0] value;
  logic [3:0] scalar;
  logic result;
  bit failed = 0;

  task check(string label, logic got, logic expected);
    if (got !== expected) begin
      $display("FAILED -- %0s: got %b, expected %b", label, got, expected);
      failed = 1;
    end
  endtask

  initial begin
    q = '{4'b1x11, 4'b0000};
    value = 4'bx000;
    scalar = 4'b0000;

    check("queue x on left", value inside {q}, 1'bx);
    check("literal set x on left", value inside {4'b1x11, 4'b0000}, 1'bx);
    check("scalar set x on left", value inside {scalar}, 1'bx);
    check("queue rhs wildcard", 4'b1011 inside {q}, 1'b1);
    check("queue mismatch", 4'b0101 inside {q}, 1'b0);
    check("queue known hit", 4'b0000 inside {q}, 1'b1);

    if (!failed) $display("PASSED");
  end
endmodule
