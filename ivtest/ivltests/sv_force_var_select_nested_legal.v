module sv_force_var_select_nested_legal;
  logic [3:0] d1[], q1[$], m[2][];
  initial begin
    force d1[0] = 4'h1;
    release d1[0];
    force q1[0] = 4'h1;
    release q1[0];
    force m[0][0] = 4'h1;
    release m[0][0];
  end
endmodule
