module sv_ref_queue_type_mismatch_fail;
  logic [7:0] actual[$];
  task automatic consume(ref bit [7:0] formal[$]);
  endtask
  initial consume(actual);
endmodule
