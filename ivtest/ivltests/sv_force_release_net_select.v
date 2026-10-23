module sv_force_release_net_select;
  wire [3:0] q = 4'b0000;
  initial begin
    force q[0] = 1'b1;
    force q[3:2] = 2'b10;
    release q[0];
    release q[3:2];
    $display("net-select-ok");
  end
endmodule
