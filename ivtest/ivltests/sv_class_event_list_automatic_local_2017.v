module core_automatic_local;
  class worker_t;
    class cfg_t; logic member; endclass
    cfg_t cfg;
    int wakes;
    function new; cfg = new; endfunction
    task automatic run(input bit drive_member);
      logic [3:0] local_value = 4'h0;
      fork
        begin
          #1;
          if (drive_member) cfg.member = 1'b1;
          else local_value = 4'ha;
        end
      join_none
      @(cfg.member, local_value);
      wakes++;
    endtask
  endclass
  worker_t a, b;
  initial begin
    a = new; b = new;
    fork a.run(1); b.run(0); join
    if (a.wakes != 1 || b.wakes != 1) $fatal(1, "automatic local contexts crossed/missed");
    if (a.cfg.member != 1 || b.cfg.member != 0) $fatal(1, "automatic source isolation failed");
    $display("PASS core automatic local"); $finish;
  end
endmodule
