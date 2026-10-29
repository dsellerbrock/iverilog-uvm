module issue1343_nba_sync;
  reg x = 0;

  initial begin
    $issue1343_register(x);
    #5 x <= 1;
    #1 $finish;
  end
endmodule
