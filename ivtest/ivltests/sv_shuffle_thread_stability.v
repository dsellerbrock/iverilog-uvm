// IEEE 1800-2017/2023 18.14.2: shuffle results are independent of
// thread execution order.
module test;
  int left_first[4], right_first[4];
  int left_second[4], right_second[4];
  int i;

  initial begin
    fork
      begin
        automatic process p;
        p = process::self();
        p.srandom(101);
        left_first[0]=1; left_first[1]=2; left_first[2]=3; left_first[3]=4;
        left_first.shuffle();
      end
      begin
        automatic process p;
        p = process::self();
        p.srandom(202);
        #1;
        right_first[0]=1; right_first[1]=2; right_first[2]=3; right_first[3]=4;
        right_first.shuffle();
      end
    join

    fork
      begin
        automatic process p;
        p = process::self();
        p.srandom(101);
        #1;
        left_second[0]=1; left_second[1]=2; left_second[2]=3; left_second[3]=4;
        left_second.shuffle();
      end
      begin
        automatic process p;
        p = process::self();
        p.srandom(202);
        right_second[0]=1; right_second[1]=2; right_second[2]=3; right_second[3]=4;
        right_second.shuffle();
      end
    join

    for (i = 0; i < 4; i = i + 1) begin
      if (left_first[i] !== left_second[i])
        $fatal(1, "left thread shuffle changed with execution order");
      if (right_first[i] !== right_second[i])
        $fatal(1, "right thread shuffle changed with execution order");
    end
    $display("PASS");
  end
endmodule
