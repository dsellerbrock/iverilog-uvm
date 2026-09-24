interface no_candidate_a_if;
  logic value;
  task drive(); value = 1'b1; endtask
endinterface

interface no_candidate_b_if;
  logic value;
  task drive(); value = 1'b1; endtask
endinterface

module no_candidate_unrelated;
  no_candidate_b_if b();
  virtual no_candidate_a_if a;
  assign b.value = 1'b0;

  initial begin
    if ($test$plusargs("CALL_UNBOUND_A")) a.drive();
    #1;
    if (b.value !== 1'b0) $fatal(1, "unused b task disturbed continuous driver");
    $display("PASSED");
    $finish(0);
  end
endmodule

module no_candidate_same_type;
  no_candidate_a_if a_inst();
  virtual no_candidate_a_if a;
  assign a_inst.value = 1'b0;

  initial begin
    a = a_inst;
    a.drive();
  end
endmodule
