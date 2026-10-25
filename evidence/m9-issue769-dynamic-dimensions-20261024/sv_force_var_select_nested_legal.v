module sv_force_var_select_nested_legal;
  logic [3:0] d1[], d2[][], q2[$][$], m[2][], e[][2];
  initial begin
    force d1[0] = 4'h1;
    force d2[0][0] = 4'h1;
    release d2[0][0];
    force q2[0][0] = 4'h1;
    force m[0][0] = 4'h1;
    force e[0][0] = 4'h1;
  end
endmodule
