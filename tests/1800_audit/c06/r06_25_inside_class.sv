virtual class C#(parameter type T = logic, parameter SIZE = 1); typedef logic [SIZE-1:0] t_vector; endclass
class U; C#(bit,3)::t_vector pv; function int w(); return $bits(pv); endfunction endclass
module m; U u = new; initial $display("IC bits=%0d", u.w()); endmodule
