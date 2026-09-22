module core_prequeued_regions;
  class cfg_t; logic on; endclass
  class driver_t;
    cfg_t cfg;
    logic pulses;
    int wakes;
    function new; cfg = new; cfg.on = 0; pulses = 0; endfunction
    task automatic wait_one;
      @(cfg.on, pulses);
      wakes++;
    endtask
  endclass
  driver_t d;
  reactive_writer rw();
  initial d = new;
  initial begin
    wait (d != null);
    d.wait_one();
    d.wait_one();
  end
  initial begin
    wait (d != null);
    #0 d.pulses = 1'b1;
  end
  initial begin
    #3;
    if (d.wakes != 2) $fatal(1, "prequeued writers missed, wakes=%0d", d.wakes);
    $display("PASS core prequeued regions");
    $finish;
  end
endmodule

program automatic reactive_writer;
  initial begin
    #1 core_prequeued_regions.d.cfg.on = 1'b1;
    #3;
  end
endprogram
