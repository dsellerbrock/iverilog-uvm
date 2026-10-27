// IEEE 1800-2017/2023 9.7: a process cannot await its own termination.
module sv_process_await_self;
  initial begin
    process current;
    current = process::self();
    current.await();
    $display("REACHED_AFTER_AWAIT_SELF");
  end
endmodule
