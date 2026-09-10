// IEEE 1800-2017/2023 9.3.2, 9.7, 18.14.1 and 18.14.2.
// Every fork child has its own process and consumes one parent RNG seed.
module main;
  process parent_process, child_process;
  int unsigned draw;
  string expected_parent_state;

  function void prepare_rng();
    parent_process.srandom(12345);
    draw = $urandom;
    expected_parent_state = parent_process.get_randstate();
    parent_process.srandom(12345);
  endfunction

  function void check_rng();
    if (parent_process.get_randstate() != expected_parent_state)
      $fatal(1, "singleton child did not consume exactly one parent seed");
  endfunction

  function void check_process();
    if (child_process == null || child_process == parent_process)
      $fatal(1, "singleton fork child lost its process identity");
    if (child_process.status() != process::FINISHED)
      $fatal(1, "joined child process did not finish");
  endfunction

  task automatic check_task;
    process caller, branch;
    caller = process::self();
    if (caller != parent_process)
      $fatal(1, "task call created a process");
    fork branch = process::self(); join
    if (branch == caller) $fatal(1, "task singleton join lost its process");
    fork branch = process::self(); join_any
    if (branch == caller) $fatal(1, "task singleton join_any lost its process");
  endtask

  initial begin
    parent_process = process::self();
    prepare_rng();
    fork
      begin
        child_process = process::self();
        repeat (3) draw = $urandom;
      end
    join
    check_process();
    check_rng();

    prepare_rng();
    fork
      begin
        child_process = process::self();
        repeat (3) draw = $urandom;
      end
    join_any
    check_process();
    check_rng();

    // Named and detached singleton process controls.
    fork : named_singleton child_process = process::self(); join
    check_process();
    fork child_process = process::self(); join_none
    wait fork;
    check_process();
    check_task();

    // Empty child preservation must also retain the singleton process.
    prepare_rng();
    fork ; join
    check_rng();
    prepare_rng();
    fork begin end join_any
    check_rng();

    // A sequential statement must stay in the enclosing process.
    begin : sequential_control
      child_process = process::self();
    end
    if (child_process != parent_process)
      $fatal(1, "sequential block created a process");
    $display("PASSED");
  end
endmodule
