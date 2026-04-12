module test;
  class holder;
    int q[$];
  endclass

  holder h;

  initial begin
    h = new;

    fork
      begin
        wait (h.q.size() != 0);
        if (h.q.size() != 1 || h.q[0] != 42) begin
          $display("FAIL size=%0d val=%0d", h.q.size(), h.q.size() ? h.q[0] : -1);
          $finish(1);
        end
        $display("PASS");
      end
      begin
        #0;
        h.q.insert(h.q.size(), 42);
      end
    join
  end
endmodule
