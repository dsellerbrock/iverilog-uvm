module sv_packed_wide_select_monitor;
  logic [7:0] value = 8'ha5;
  initial begin
    $monitor("wide=%b partial=%b",
             value[64'h1_0000_0000 +: 4], value[-2 +: 4]);
    #1 value = 8'h5a;
    #1 $display("PASSED");
  end
endmodule
