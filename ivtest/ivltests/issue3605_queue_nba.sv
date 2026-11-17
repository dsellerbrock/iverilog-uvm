module issue3605_queue_nba;
  int q[$];
  int bounded[$:3];
  initial begin
    q[0] <= 1;
    q[$] <= 2;
    bounded[0] <= 3;
  end
endmodule
