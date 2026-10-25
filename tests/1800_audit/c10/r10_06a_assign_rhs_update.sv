module r10_06a_assign_rhs_update;
  int pass = 0, fail = 0;
  task automatic ck(input string id, input bit c);
    if (c) pass++; else begin fail++; $display("FAIL %s", id); end
  endtask
  logic a, b;
  initial begin
    assign b = a;
    a = 0; #1 ck("assign_rhs_low", b === 1'b0);
    a = 1; #1 ck("assign_rhs_high", b === 1'b1);
    deassign b;
    $display("RESULT pass=%0d fail=%0d", pass, fail);
    $finish;
  end
endmodule
