virtual class C#(parameter type T = logic, parameter SIZE = 4); typedef logic [SIZE-1:0] t_vector; endclass
module m; C#()::t_vector v; initial $display("DS bits=%0d", $bits(v)); endmodule
