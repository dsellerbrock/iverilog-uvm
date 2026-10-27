module format_undefined_spec;
  initial begin
    $display("value=%q", 1);
    $display("unexpected continuation");
  end
endmodule
