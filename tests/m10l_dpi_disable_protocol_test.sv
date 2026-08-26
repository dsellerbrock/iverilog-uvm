// IEEE 1800-2017/2023 35.9: positive DPI disable-protocol coverage.
//
// The status returned by an exported task is not an SV task result. It tells
// its C caller whether the *enclosing mixed-language call chain* was disabled:
//   - normal completion returns 0;
//   - directly disabling the exported task also returns 0 and leaves C normal;
//   - disabling an ancestor of the imported task returns 1 and resumes C once
//     so it can clean up and acknowledge with its own return value of 1.
//
// An imported function has no task-status return channel. One case makes
// an exported SV function non-locally disable the named fork containing its C
// caller. C must observe the disabled state, clean up, and acknowledge through
// svAckDisabledState() before returning. Values returned by that disabled
// function are intentionally not inspected because 35.9 makes them undefined.
module m10l_dpi_disable_protocol_test;
  import "DPI-C" context task c_normal();
  import "DPI-C" context task c_direct();
  import "DPI-C" context task c_ancestor();
  import "DPI-C" context task c_concurrent(input int id);
  import "DPI-C" context task c_resumed_reentry();
  import "DPI-C" context task c_resumed_vpi_context(input int id);
  import "DPI-C" context function int c_disabled_function();
  import "DPI-C" function int c_observe(input int selector);

  localparam int OBS_NORMAL_STATUS       = 0;
  localparam int OBS_NORMAL_QUERY        = 1;
  localparam int OBS_NORMAL_CONTINUED    = 2;
  localparam int OBS_DIRECT_STATUS       = 3;
  localparam int OBS_DIRECT_QUERY        = 4;
  localparam int OBS_DIRECT_CONTINUED    = 5;
  localparam int OBS_ANCESTOR_STATUS     = 6;
  localparam int OBS_ANCESTOR_QUERY      = 7;
  localparam int OBS_ANCESTOR_RESUMED    = 8;
  localparam int OBS_ANCESTOR_CLEANUP    = 9;
  localparam int OBS_FUNCTION_QUERY      = 10;
  localparam int OBS_FUNCTION_RESUMED    = 11;
  localparam int OBS_FUNCTION_CLEANUP    = 12;
  localparam int OBS_FUNCTION_ACKED      = 13;
  localparam int OBS_CONCURRENT_STATUS_0 = 14;
  localparam int OBS_CONCURRENT_QUERY_0  = 15;
  localparam int OBS_CONCURRENT_STATUS_1 = 16;
  localparam int OBS_CONCURRENT_QUERY_1  = 17;
  localparam int OBS_REENTRY_STATUS       = 18;
  localparam int OBS_REENTRY_QUERY        = 19;
  localparam int OBS_REENTRY_RESUMED      = 20;
  localparam int OBS_REENTRY_CLEANUP      = 21;
  localparam int OBS_VPI_CONTEXT_ERROR_0  = 22;
  localparam int OBS_VPI_CONTEXT_ERROR_1  = 23;

  int errors = 0;
  int ignored_function_result;

  int normal_export_entered = 0;
  int normal_export_tail = 0;
  int normal_import_tail = 0;

  int direct_export_entered = 0;
  int direct_export_tail = 0;
  int direct_import_tail = 0;

  int ancestor_export_entered = 0;
  int ancestor_export_tail = 0;
  int ancestor_import_tail = 0;
  int ancestor_sibling_entered = 0;
  int ancestor_sibling_tail = 0;

  int function_export_entered = 0;
  int function_export_tail = 0;
  int function_import_tail = 0;
  int function_controller_tail = 0;

  int reentry_delay_entered = 0;
  int reentry_delay_tail = 0;
  int reentry_disable_entered = 0;
  int reentry_disable_tail = 0;
  int reentry_import_tail = 0;
  int reentry_controller_tail = 0;

  int vpi_context_delay_entered[2] = '{0, 0};
  int vpi_context_delay_tail[2] = '{0, 0};
  int vpi_context_import_tail[2] = '{0, 0};
  int vpi_context_local_result[2] = '{-1, -1};

  int concurrent_export_entered[2] = '{0, 0};
  int concurrent_export_tail[2] = '{0, 0};
  int concurrent_import_tail[2] = '{0, 0};

  task automatic check_value(input int got, input int expected,
                             input string description);
    if (got != expected) begin
      $display("FAIL %s: got %0d, expected %0d", description, got, expected);
      errors++;
    end
  endtask

  task automatic sv_normal_task();
    normal_export_entered++;
    #2;
    normal_export_tail++;
  endtask
  export "DPI-C" task sv_normal_task;

  task automatic sv_direct_task();
    direct_export_entered++;
    #100;
    direct_export_tail++;
  endtask
  export "DPI-C" task sv_direct_task;

  task automatic sv_ancestor_task();
    ancestor_export_entered++;
    #100;
    ancestor_export_tail++;
  endtask
  export "DPI-C" task sv_ancestor_task;

  task automatic sv_concurrent_task(input int id);
    concurrent_export_entered[id]++;
    #(id == 0 ? 100 : 3);
    concurrent_export_tail[id]++;
  endtask
  export "DPI-C" task sv_concurrent_task;

  // The first export completes normally and resumes its parked C caller.
  // Before returning from that resumed import, C calls the synchronous
  // function below. Its disable exercises re-entrant cleanup while the
  // scheduler still owns the completed export child.
  task automatic sv_reentry_delay_task();
    reentry_delay_entered++;
    #2;
    reentry_delay_tail++;
  endtask
  export "DPI-C" task sv_reentry_delay_task;

  function automatic int sv_reentry_disable_caller();
    reentry_disable_entered++;
    disable reentry_victim;
    reentry_disable_tail++;
    return 456;
  endfunction
  export "DPI-C" function sv_reentry_disable_caller;

  task automatic sv_vpi_context_delay_task(input int id);
    vpi_context_delay_entered[id]++;
    #(id == 0 ? 2 : 3);
    vpi_context_delay_tail[id]++;
  endtask
  export "DPI-C" task sv_vpi_context_delay_task;

  // C resolves and writes this automatic local through VPI after the exported
  // delay resumes. Keep two activations alive to check caller-specific VPI
  // context selection rather than only the single-activation case.
  task automatic run_vpi_context_case(input int id);
    int cleanup_probe = -1;
    c_resumed_vpi_context(id);
    vpi_context_local_result[id] = cleanup_probe;
    vpi_context_import_tail[id]++;
    #10;
  endtask

  // This executes on the exported-function side of
  //   SV function_victim -> C import -> SV export.
  // Killing function_victim disables the imported function's ancestor and
  // must return control to C in the disabled state. Neither tail is legal.
  function automatic int sv_disable_function_caller();
    function_export_entered++;
    disable function_victim;
    function_export_tail++;
    return 123;
  endfunction
  export "DPI-C" function sv_disable_function_caller;

  initial begin
    // Normal time-consuming completion exercises the coroutine resume path,
    // but neither status API is in the disabled state.
    c_normal();
    normal_import_tail++;

    // Directly disabling only the exported task is the explicit 35.9 special
    // case: C resumes with task status 0 and svIsDisabledState() == 0, then the
    // imported task and its SV caller both continue normally.
    fork : direct_case
      begin
        c_direct();
        direct_import_tail++;
      end
      begin
        wait (direct_export_entered == 1);
        #1;
        disable sv_direct_task;
      end
    join

    // Two foreign task stacks are parked at once. Disable only id 0 while
    // id 1 completes normally; their saved query/status records must not
    // share a singleton runtime flag.
    fork : concurrent_case
      begin : concurrent_victim
        c_concurrent(0);
        concurrent_import_tail[0]++;
      end
      begin
        c_concurrent(1);
        concurrent_import_tail[1]++;
      end
      begin
        wait (concurrent_export_entered[0] == 1);
        #1;
        disable concurrent_victim;
      end
    join

    // Here the target is an ancestor of the imported task. Its exported task
    // is parked at #100 when the sibling kills the caller branch. The C stack
    // must be resumed exactly once for cleanup; both SV tails remain killed.
    fork : ancestor_case
      begin : ancestor_victim
        // Leave an ordinary join_any survivor owned by this caller before
        // parking on the DPI export. Disabling the caller must kill both
        // forms of outstanding work while still resuming C cleanup once.
        fork
          begin
            #0;
          end
          begin
            ancestor_sibling_entered++;
            #200;
            ancestor_sibling_tail++;
          end
        join_any
        c_ancestor();
        ancestor_import_tail++;
      end
      begin
        wait (ancestor_export_entered == 1);
        #1;
        disable ancestor_victim;
      end
    join

    // A function cannot call an exported task, so use an exported function to
    // synchronously disable the enclosing named fork. C acknowledges through
    // svAckDisabledState(); this controller resumes outside the disabled fork.
    fork : function_victim
      begin
        ignored_function_result = c_disabled_function();
        function_import_tail++;
      end
    join
    function_controller_tail++;

    // C is first parked on a normally completing exported task. It resumes
    // from the scheduler and immediately calls an exported function that
    // disables this ancestor. The runtime must retain both the imported-task
    // thread and the old export child until C has queried, cleaned up, and
    // returned acknowledgement 1; neither disabled SV tail may execute.
    fork : reentry_victim
      begin
        c_resumed_reentry();
        reentry_import_tail++;
      end
    join
    reentry_controller_tail++;

    // Direct VPI work performed by resumed C must use the imported task's
    // automatic activation, not the just-ended exported-task child.
    fork
      run_vpi_context_case(0);
      run_vpi_context_case(1);
    join

    // Outlive the killed #100 task activations. This makes any stale scheduled
    // continuation, and all C cleanup recorded after either disable, observable
    // from a later, ordinary DPI invocation.
    #110;

    check_value(normal_export_entered, 1, "normal export entry count");
    check_value(normal_export_tail, 1, "normal export tail count");
    check_value(normal_import_tail, 1, "normal import tail count");
    check_value(c_observe(OBS_NORMAL_STATUS), 0, "normal exported-task status");
    check_value(c_observe(OBS_NORMAL_QUERY), 0, "normal disabled-state query");
    check_value(c_observe(OBS_NORMAL_CONTINUED), 1, "normal C continuation count");

    check_value(direct_export_entered, 1, "direct-disable export entry count");
    check_value(direct_export_tail, 0, "direct-disable export tail count");
    check_value(direct_import_tail, 1, "direct-disable import tail count");
    check_value(c_observe(OBS_DIRECT_STATUS), 0, "direct-disable exported-task status");
    check_value(c_observe(OBS_DIRECT_QUERY), 0, "direct-disable disabled-state query");
    check_value(c_observe(OBS_DIRECT_CONTINUED), 1, "direct-disable C continuation count");

    check_value(ancestor_export_entered, 1, "ancestor-disable export entry count");
    check_value(ancestor_export_tail, 0, "ancestor-disable export tail count");
    check_value(ancestor_import_tail, 0, "ancestor-disable import tail count");
    check_value(ancestor_sibling_entered, 1, "ancestor sibling entry count");
    check_value(ancestor_sibling_tail, 0, "ancestor sibling tail count");
    check_value(c_observe(OBS_ANCESTOR_STATUS), 1, "ancestor-disable exported-task status");
    check_value(c_observe(OBS_ANCESTOR_QUERY), 1, "ancestor-disable disabled-state query");
    check_value(c_observe(OBS_ANCESTOR_RESUMED), 1, "ancestor-disable C resume count");
    check_value(c_observe(OBS_ANCESTOR_CLEANUP), 1, "ancestor-disable C cleanup count");

    check_value(function_export_entered, 1, "function-disable export entry count");
    check_value(function_export_tail, 0, "function-disable export tail count");
    check_value(function_import_tail, 0, "function-disable import tail count");
    check_value(function_controller_tail, 1, "function-disable controller tail count");
    check_value(c_observe(OBS_FUNCTION_QUERY), 1, "disabled-function state query");
    check_value(c_observe(OBS_FUNCTION_RESUMED), 1, "disabled-function C resume count");
    check_value(c_observe(OBS_FUNCTION_CLEANUP), 1, "disabled-function cleanup count");
    check_value(c_observe(OBS_FUNCTION_ACKED), 1, "disabled-function acknowledgment count");

    check_value(reentry_delay_entered, 1, "re-entry delay export entry count");
    check_value(reentry_delay_tail, 1, "re-entry delay export tail count");
    check_value(reentry_disable_entered, 1, "re-entry disabling export entry count");
    check_value(reentry_disable_tail, 0, "re-entry disabling export tail count");
    check_value(reentry_import_tail, 0, "re-entry disabled import tail count");
    check_value(reentry_controller_tail, 1, "re-entry controller tail count");
    check_value(c_observe(OBS_REENTRY_STATUS), 0, "pre-disable re-entry task status");
    check_value(c_observe(OBS_REENTRY_QUERY), 1, "re-entry disabled-state query");
    check_value(c_observe(OBS_REENTRY_RESUMED), 1, "re-entry C resume count");
    check_value(c_observe(OBS_REENTRY_CLEANUP), 1, "re-entry C cleanup count");

    check_value(vpi_context_delay_entered[0], 1, "VPI context export 0 entry");
    check_value(vpi_context_delay_tail[0], 1, "VPI context export 0 tail");
    check_value(vpi_context_import_tail[0], 1, "VPI context import 0 tail");
    check_value(vpi_context_local_result[0], 37, "VPI context local 0 write");
    check_value(c_observe(OBS_VPI_CONTEXT_ERROR_0), 0, "VPI context C error 0");
    check_value(vpi_context_delay_entered[1], 1, "VPI context export 1 entry");
    check_value(vpi_context_delay_tail[1], 1, "VPI context export 1 tail");
    check_value(vpi_context_import_tail[1], 1, "VPI context import 1 tail");
    check_value(vpi_context_local_result[1], 38, "VPI context local 1 write");
    check_value(c_observe(OBS_VPI_CONTEXT_ERROR_1), 0, "VPI context C error 1");

    check_value(concurrent_export_entered[0], 1, "disabled concurrent export entry");
    check_value(concurrent_export_tail[0], 0, "disabled concurrent export tail");
    check_value(concurrent_import_tail[0], 0, "disabled concurrent import tail");
    check_value(c_observe(OBS_CONCURRENT_STATUS_0), 1, "disabled concurrent status");
    check_value(c_observe(OBS_CONCURRENT_QUERY_0), 1, "disabled concurrent query");
    check_value(concurrent_export_entered[1], 1, "normal concurrent export entry");
    check_value(concurrent_export_tail[1], 1, "normal concurrent export tail");
    check_value(concurrent_import_tail[1], 1, "normal concurrent import tail");
    check_value(c_observe(OBS_CONCURRENT_STATUS_1), 0, "normal concurrent status");
    check_value(c_observe(OBS_CONCURRENT_QUERY_1), 0, "normal concurrent query");

    if (errors == 0) begin
      $display("PASS m10l_dpi_disable_protocol_test");
      $finish(0);
    end
    $display("FAIL m10l_dpi_disable_protocol_test: %0d checks failed", errors);
    $finish(1);
  end
endmodule
