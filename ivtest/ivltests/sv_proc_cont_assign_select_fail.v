module sv_proc_cont_assign_select_fail;
  logic [3:0] q;
  initial begin
    assign q[0] = 1'b1;
    assign q[2:1] = 2'b10;
  end
endmodule
