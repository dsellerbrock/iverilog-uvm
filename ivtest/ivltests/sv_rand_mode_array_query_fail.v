class C;
  rand bit [3:0] m[3][2];
  rand bit [3:0] d[4];
endclass
module sv_rand_mode_array_query_fail;
  initial begin
    C x;
    x = new;
    $display("sub-array query=%0d", x.m[2].rand_mode());
  end
endmodule
