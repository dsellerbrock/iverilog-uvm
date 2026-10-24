module sv_force_release_var_select_fail;
  logic [3:0] q;
  initial begin
    force q[1] = 1'b1;
    release q[1];
    force q[3:2] = 2'b10;
    release q[3:2];
  end
endmodule
