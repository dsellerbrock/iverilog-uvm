// IEEE 1800-2017/2023 9.3.4 and 9.6.2: a named child of an
// anonymous join_none fork remains visible to a later disable.
class worker;
  int ticks;

  task run();
    int stopped_at;
    fork
      begin : watcher
        forever begin
          #1 ticks++;
        end
      end : watcher
    join_none

    #5;
    if (ticks == 0) $fatal(1, "watcher did not start");
    disable watcher;
    stopped_at = ticks;
    #5;
    if (ticks != stopped_at) $fatal(1, "watcher survived disable");
  endtask
endclass

module test;
  worker w;
  initial begin
    w = new;
    w.run();
    $display("PASSED");
    $finish;
  end
endmodule
