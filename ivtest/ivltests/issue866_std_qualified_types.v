module tb;
  class semaphore;
    int marker;
    function new(int value);
      marker = value;
    endfunction
  endclass

  semaphore shadowed;
  std::semaphore sem;
  std::mailbox #(int) mb;
  std::process proc;
  int received;

  initial begin
    shadowed = new(42);
    sem = new(1);
    mb = new();
    mb.put(6);
    mb.get(received);
    proc = std::process::self();

    $display("SHADOW %0d", shadowed.marker);
    $display("SEMAPHORE %0d", sem.try_get());
    $display("MAILBOX %0d", received);
    $display("PROCESS %0d", proc != null &&
             proc.status() == std::process::RUNNING);
  end
endmodule
