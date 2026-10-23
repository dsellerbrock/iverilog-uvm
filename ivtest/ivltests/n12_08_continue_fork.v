module n12_08_continue_fork;
initial begin
  for (int i=0; i<2; i++) fork continue; join
end
endmodule
