module p26_07_std_randomize_only;
  int v, ok;
  initial begin
    ok = std::randomize(v) with { v inside {[3:3]}; };
    $display("R1 %0d %0d", ok, v);
  end
endmodule
