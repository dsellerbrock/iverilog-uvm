// A concatenation of scalar queue/darray ELEMENTS (not the queue/darray
// itself) is an ordinary packed bit-vector concatenation and must remain
// unaffected by rejecting a queue/darray operand (see the companion
// sv_concat_postfix_select_queue_operand_fail.v negative test).
module test;
  bit [3:0] q[$] = {4'ha, 4'hb};

  initial begin
    if ({q[0], q[1]}[3:0] !== 4'hb)
      $fatal(1, "queue-element concat select");
    $display("PASSED");
  end
endmodule
