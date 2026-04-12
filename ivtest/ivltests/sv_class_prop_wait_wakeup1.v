module test;
  class holder;
    int v;
  endclass

  holder h;
  int got;

  initial begin
    h = new;
    got = 0;

    fork
      begin
        wait (h.v != 0);
        got = h.v;
      end
    join_none

    #1;
    h.v = 42;
    #1;

    if (got !== 42) begin
      $display("FAIL got=%0d v=%0d", got, h.v);
      $finish_and_return(1);
    end

    $display("PASS");
  end
endmodule
