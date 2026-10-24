// IEEE 1800-2017/2023 15.3.1: a negative initial count is a key deficit.
module sv_semaphore_negative_initial_count;
  semaphore sem;
  bit get_done = 0;

  initial begin
    sem = new(-2);
    if (sem.try_get(1)) $fatal(1, "try_get succeeded with a negative count");

    sem.put(1);
    if (sem.try_get(1)) $fatal(1, "try_get succeeded while count was still negative");
    sem.put(1);
    if (sem.try_get(1)) $fatal(1, "try_get succeeded when count was zero");
    sem.put(1);
    if (!sem.try_get(1)) $fatal(1, "try_get failed when count became positive");

    sem = new(-1);
    fork
      begin
        sem.get(1);
        get_done = 1;
      end
    join_none

    #1;
    if (get_done) $fatal(1, "get completed with a negative count");
    sem.put(1);
    #1;
    if (get_done) $fatal(1, "get completed when count was zero");
    sem.put(1);
    #1;
    if (!get_done) $fatal(1, "get did not complete when count became positive");

    $display("PASSED");
    $finish;
  end
endmodule
