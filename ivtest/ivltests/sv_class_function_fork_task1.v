module test;
  class worker_t;
    static int static_seen;
    int inst_seen;

    static task static_work(int value);
      static_seen = value;
    endtask

    task inst_work(int value);
      inst_seen = value;
    endtask

    static function void launch_static(int value);
      fork
        begin
          static_work(value);
        end
      join_none
    endfunction

    function void launch_inst(int value);
      fork
        begin
          inst_work(value);
        end
      join_none
    endfunction
  endclass

  initial begin
    worker_t w;

    w = new;

    worker_t::launch_static(17);
    w.launch_inst(23);

    #0;

    if (worker_t::static_seen != 17) begin
      $display("FAIL: static_seen=%0d", worker_t::static_seen);
      $finish(1);
    end

    if (w.inst_seen != 23) begin
      $display("FAIL: inst_seen=%0d", w.inst_seen);
      $finish(1);
    end

    $display("PASS");
  end
endmodule
