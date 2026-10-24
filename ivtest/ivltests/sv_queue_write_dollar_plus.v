module sv_queue_write_dollar_plus;
  int q[$] = '{1, 2};
  int b[$:3] = '{1, 2, 3, 4};

  initial begin
    q[$+1] = 50;
    $display("q size=%0d last=%0d", q.size(), q[$]);

    b[$+1] = 60;
    $display("b size=%0d last=%0d", b.size(), b[$]);
  end
endmodule
