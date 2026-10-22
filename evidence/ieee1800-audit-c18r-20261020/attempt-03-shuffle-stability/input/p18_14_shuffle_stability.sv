// IEEE 1800-2017/2023 §18.14.2: shuffle results are independent of
// sibling-thread execution order.
module test;
  int unsigned arr_a[8];
  int unsigned arr_b[8];
  process parent_thread;

  initial begin
    foreach (arr_a[i]) begin
      arr_a[i] = i;
      arr_b[i] = i + 8;
    end

    parent_thread = process::self();
    parent_thread.srandom(101);
    fork
      begin
`ifndef DELAY_A
        #1;
`endif
        arr_a.shuffle();
        $write("A=");
        foreach (arr_a[i]) $write("%0d,", arr_a[i]);
        $display("");
      end
      begin
`ifdef DELAY_A
        #1;
`endif
        arr_b.shuffle();
        $write("B=");
        foreach (arr_b[i]) $write("%0d,", arr_b[i]);
        $display("");
      end
    join

    $display("PASS shuffle thread stability");
    $finish;
  end
endmodule
