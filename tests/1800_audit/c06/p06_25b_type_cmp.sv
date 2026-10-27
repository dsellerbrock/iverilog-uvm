virtual class C#(parameter type T = logic, parameter SIZE = 1);
  typedef logic [SIZE-1:0] t_vector;
endclass
module p06_25b;
  int pass = 0, fail = 0;
  task automatic ck(input string id, input bit c);
    if (c) pass++; else begin fail++; $display("FAIL %s", id); end
  endtask
  initial begin
    ck("same_spec_matches", type(C#(bit,3)::t_vector) == type(C#(bit,3)::t_vector));
    ck("diff_spec_distinct", type(C#(bit,3)::t_vector) != type(C#(bit,4)::t_vector));
    $display("RESULT pass=%0d fail=%0d", pass, fail);
  end
endmodule
