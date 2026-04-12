module test;
  class holder;
    static int q[$];
    static bit done;

    static task get(output int out);
      wait (q.size() != 0);
      out = q.pop_front();
      done = 1;
    endtask

    static function void put(int value);
      q.push_back(value);
    endfunction

    static function bit donef();
      return done;
    endfunction

    static function int sizef();
      return q.size();
    endfunction
  endclass

  int got;

  initial begin
    got = -1;

    fork
      holder::get(got);
    join_none

    #1;
    holder::put(42);
    #1;

    if (!holder::donef() || got != 42 || holder::sizef() != 0) begin
      $display("FAIL done=%0d got=%0d qsize=%0d",
               holder::donef(), got, holder::sizef());
      $finish_and_return(1);
    end

    $display("PASS");
  end
endmodule
