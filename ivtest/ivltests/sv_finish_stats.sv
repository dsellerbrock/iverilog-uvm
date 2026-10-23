module sv_finish_stats;
initial begin
  #3;
  $display("PASSED");
  $finish(2);
end
endmodule
