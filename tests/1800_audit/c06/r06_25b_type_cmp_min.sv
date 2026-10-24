virtual class C#(parameter type T = logic, parameter SIZE = 1);
  typedef logic [SIZE-1:0] t_vector;
endclass
module m;
  C#(bit,3)::t_vector v;
  initial $display("MATCH=%0d", type(v) == type(v));
endmodule
