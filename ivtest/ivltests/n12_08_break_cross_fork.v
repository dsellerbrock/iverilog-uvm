module n12_08_break_cross_fork;
initial begin
  for (int i=0; i<1; i++) begin
    fork begin break; end join
  end
end
endmodule
