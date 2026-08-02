module singleton_unpacked_array_continuous_assign_test;
  wire [11:0] prescaler [1];
  wire [7:0] step [1];
  wire [63:0] mtimecmp [1][1];
  wire [7:0] selected_only [1];
  wire nested_selected [1][1];

  assign prescaler = '{12'habc};
  assign step = '{8'h5a};
  assign mtimecmp = '{'{64'h0123_4567_89ab_cdef}};
  assign selected_only[0] = 8'hc3;
  assign nested_selected[0][0] = 1'b1;

  initial begin
    #1;
    if (prescaler[0] !== 12'habc || step[0] !== 8'h5a ||
        mtimecmp[0][0] !== 64'h0123_4567_89ab_cdef ||
        selected_only[0] !== 8'hc3 || nested_selected[0][0] !== 1'b1)
      $fatal(1, "singleton unpacked-array continuous assignment failed");
    $display("PASS: singleton unpacked-array continuous assignment");
  end
endmodule
