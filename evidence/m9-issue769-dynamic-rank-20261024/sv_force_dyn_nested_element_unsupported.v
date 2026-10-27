module sv_force_dyn_nested_element_unsupported;
  logic [3:0] d2[][], q2[$][$], e[][2];
  initial begin
    force d2[0][0] = 4'h1;
    release d2[0][0];
    force q2[0][0] = 4'h1;
    release q2[0][0];
    force e[0][0] = 4'h1;
    release e[0][0];
  end
endmodule
