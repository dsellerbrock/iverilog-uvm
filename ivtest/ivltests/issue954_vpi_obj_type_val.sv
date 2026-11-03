module top;
  integer ii = -5;
  time tt = 64'h1_0000_0002;
  logic [63:0] vec = 64'h1_0000_0002;
  real rr = 1.25;
  logic ss = 1'b1;

  initial begin
    #1;
    $issue954_check_obj_type_val;
    $finish;
  end
endmodule
