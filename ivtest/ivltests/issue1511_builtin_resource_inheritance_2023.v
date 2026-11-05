class issue1511_sem_base extends semaphore;
  int acquired;

  function new(int count = 0);
    super.new(count);
  endfunction

  virtual task lock();
    this.get();
    acquired++;
  endtask
endclass

class issue1511_sem extends issue1511_sem_base;
  function new(int count = 0);
    super.new(count);
  endfunction

  virtual task lock();
    super.lock();
  endtask
endclass

class issue1511_mbox_base extends mailbox #(int);
  int received;

  function new(int bound = 0);
    super.new(bound);
  endfunction

  virtual task take();
    this.get(received);
  endtask
endclass

class issue1511_mbox extends issue1511_mbox_base;
  function new(int bound = 0);
    super.new(bound);
  endfunction

  virtual task take();
    super.take();
  endtask
endclass

module issue1511_builtin_resource_inheritance;
  issue1511_sem sem;
  semaphore sem_base_handle;
  issue1511_mbox mbox;
  mailbox #(int) mbox_base_handle;
  int got;

  initial begin
    sem = new(1);
    sem_base_handle = sem;
    if (!sem.try_get()) $fatal(1, "semaphore constructor count was lost");

    fork
      sem.lock();
      begin
        #1 sem.put();
      end
    join
    if (sem.acquired != 1) $fatal(1, "overridden semaphore helper failed");

    sem_base_handle.put();
    if (!sem_base_handle.try_get())
      $fatal(1, "upcast semaphore handle lost its resource state");

    mbox = new(1);
    mbox_base_handle = mbox;
    fork
      mbox.take();
      begin
        #1 mbox.put(17);
      end
    join
    if (mbox.received != 17) $fatal(1, "inherited mailbox get failed");

    if (!mbox.try_put(18) || mbox.num() != 1)
      $fatal(1, "inherited mailbox try_put/num failed");
    if (mbox.try_put(19)) $fatal(1, "bounded mailbox accepted an extra item");

    mbox.peek(got);
    if (got != 18 || mbox.try_peek(got) != 1 || got != 18)
      $fatal(1, "inherited mailbox peek failed");
    if (mbox_base_handle.try_get(got) != 1 || got != 18
        || mbox_base_handle.num() != 0)
      $fatal(1, "upcast mailbox handle lost its resource state");

    $display("PASSED");
  end
endmodule
