class C;
  rand bit [3:0] d[4];
endclass
module sv_rand_mode_whole_array_query_fail;
  initial begin
    C x;
    x = new;
    $display("whole-array query=%0d", x.d.rand_mode());
  end
endmodule
