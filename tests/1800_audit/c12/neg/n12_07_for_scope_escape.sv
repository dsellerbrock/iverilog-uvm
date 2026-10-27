module n12_07_for_scope_escape;
  initial begin
    for (int i = 0; i < 1; i++);
    $display("%0d", i);
  end
endmodule
