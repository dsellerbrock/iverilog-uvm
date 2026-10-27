virtual class C#(parameter type T = logic, parameter SIZE = 1);
  typedef logic [SIZE-1:0] t_vector;
  typedef T t_array [SIZE-1:0];
  typedef struct { t_vector m0 [2*SIZE-1:0]; t_array m1; } t_struct;
endclass
module p06_25a;
  int pass = 0, fail = 0;
  task automatic ck(input string id, input bit c);
    if (c) pass++; else begin fail++; $display("FAIL %s", id); end
  endtask
  typedef logic [7:0] t_t0;
  C#(t_t0,3)::t_vector v0;  C#(t_t0,3)::t_array a0;  C#(bit,4)::t_struct s0;
  initial begin
    ck("vector_bits", $bits(v0) == 3);
    ck("array_elem", $bits(a0) == 24 && $size(a0) == 3);
    ck("struct_bits", $bits(s0) == 36);
    v0 = 3'b101; a0[1] = 8'hA5; s0.m1[2] = 1;
    ck("member_rw", v0 == 5 && a0[1] == 8'hA5 && s0.m1[2] == 1);
    $display("RESULT pass=%0d fail=%0d", pass, fail);
  end
endmodule
