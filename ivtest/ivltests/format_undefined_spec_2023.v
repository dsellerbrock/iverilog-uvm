module format_undefined_spec_2023;
  initial begin
    $display("value=%q", 1);
    $display("unexpected continuation");
  end
endmodule
