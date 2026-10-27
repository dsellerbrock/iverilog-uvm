module sv_semaphore_negative_keycount;
  semaphore sem;
  int errors = 0;
  bit get_returned = 0;

  initial begin
    sem = new(1);

    sem.put(-1);
    if (!sem.try_get(1)) errors++;
    if (sem.try_get(1)) errors++;

    sem = new(1);
    if (sem.try_get(-1) != 0) errors++;
    if (!sem.try_get(1)) errors++;

    sem = new(1);
    fork
      begin
        sem.get(-1);
        get_returned = 1;
      end
    join
    if (!get_returned) errors++;
    if (!sem.try_get(1)) errors++;

    if (errors == 0) $display("PASSED");
    else $display("FAILED: %0d checks", errors);
  end
endmodule
