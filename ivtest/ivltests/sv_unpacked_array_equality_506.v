module main;
  logic a[505:0] = '{default: 1'b0};
  logic b[505:0] = '{default: 1'b0};

  initial begin
    if (a == b) $display("PASSED");
    else $fatal(1, "506-element unpacked-array equality failed");
  end
endmodule
