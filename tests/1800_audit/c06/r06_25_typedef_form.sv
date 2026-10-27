virtual class C#(parameter type T = logic, parameter SIZE = 1); typedef logic [SIZE-1:0] t_vector; endclass
typedef C#(bit,3)::t_vector tv;
module m; tv v; initial $display("TF bits=%0d", $bits(v)); endmodule
