module test;
  class holder;
    int q[$];

    task get(output int v);
      wait (q.size() != 0);
      v = q.pop_front();
    endtask

    function void put(int v);
      q.push_back(v);
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

    if (got !== 42 || h.q.size() != 0) begin
      $display("FAIL got=%0d qsize=%0d", got, h.q.size());
      $finish_and_return(1);
    end

    $display("PASS");
  end
endmodule
