module issue866_std_qualified_builtin_types;
  std::semaphore qualified_sem;
  std::mailbox #(int) mb;
  std::process p;
  int value;
  int random_value;

  initial begin
    qualified_sem = new(1);
    if (!qualified_sem.try_get(1) || qualified_sem.try_get(1))
      $fatal(1, "std::semaphore did not select the built-in class");
    qualified_sem.put(1);

    mb = new();
    mb.put(42);
    if (!mb.try_get(value) || value != 42 || mb.num() != 0)
      $fatal(1, "std::mailbox did not preserve its typed behavior");

    if (!std::randomize(random_value) with { random_value == 5; }
	|| random_value != 5)
      $fatal(1, "std::randomize control failed");

    p = std::process::self();
    if (p == null)
      $fatal(1, "std::process::self returned null");
    $display("PROCESS_RUNNING %0d", std::process::RUNNING);
    $display("QUALIFIED_TYPES_PASSED");
  end
endmodule

module issue866_std_qualified_shadow;
  class semaphore;
    function new();
    endfunction
  endclass

  std::semaphore qualified_sem;
  semaphore shadow_sem;

  initial begin
    qualified_sem = new(1);
    shadow_sem = new();
    qualified_sem.put(1);
    if (!qualified_sem.try_get(1))
      $fatal(1, "std::semaphore resolved to the shadowing class");
    $display("QUALIFIED_SHADOW_PASSED");
  end
endmodule
