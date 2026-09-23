module assoc_pop_stmt;
  int aa[int];
  initial begin
    aa[4]=9;
    aa.pop_front();
    $display("AA=%0d", aa.num());
  end
endmodule
