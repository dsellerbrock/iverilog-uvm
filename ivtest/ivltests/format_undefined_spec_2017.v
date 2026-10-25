module format_undefined_spec_2017;
  initial begin
    $display("value=%q", 1);
    $display("unexpected continuation");
  end
endmodule
