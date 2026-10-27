module sv_force_var_select_nested_fail;
  logic [3:0] d2[][], q2[$][$], m[2][], e[][2];
  initial begin
    force d2[0][0][0] = 1'b1;
    release d2[0][0][0];
    force q2[0][0][1:0] = 2'b11;
    force m[0][0][0] = 1'b1;
    force e[0][0][0] = 1'b1;
  end
endmodule
