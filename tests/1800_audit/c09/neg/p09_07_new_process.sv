module top; process p;
  initial begin p = new; $display("REACHED_AFTER_NEW p=%s", p == null ? "null" : "nonnull"); end
endmodule
