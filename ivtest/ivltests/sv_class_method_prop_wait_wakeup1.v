module test;
  class holder;
    int v;

    task get(output int out);
      wait (v != 0);
      out = v;
    endtask

    function void put(int x);
      v = x;
    endfunction
  endclass

  holder h;
  int got;

  initial begin
    h = new;
    got = -1;

    fork
      h.get(got);
    join_none

    #1;
    h.put(42);
    #1;

    if (got !== 42) begin
      $display("FAIL got=%0d v=%0d", got, h.v);
      $finish_and_return(1);
    end

    $display("PASS");
  end
endmodule
