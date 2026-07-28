// M9-7: pass/fail action blocks are arbitrary statements. A multiclock
// checker has verdict sites in both domains, but that must not restrict the
// action to the small subset of AST nodes a source-tree copier understands.
module main;
  reg c1 = 0, c2 = 0, trig = 0;
  reg fail_trig = 1, prefix_ok = 0, suffix_ok = 0;
  reg sc1 = 0, sc2 = 0;
  reg same_trig = 1, same_prefix = 1, same_suffix = 0;
  int pass_count = 0;
  int prefix_fail = 0;
  int suffix_fail = 0;
  int timed_started = 0;
  int timed_done = 0;
  int timed_errors = 0;
  int region_errors = 0;
  reg region_seen = 0;
  int case_count = 0;
  int event_count = 0;
  int fork_repeat_count = 0;
  int fork_delay_count = 0;
  int bare_hits = 0;
  int same_slot_pass = 0;
  int same_slot_fail = 0;
  int same_fail_done = 0;
  int mode = 1;
  int i;
  event action_done;

  class counter;
    int hits = 0;
    task hit;
      hits++;
    endtask
  endclass

  counter obj;

  function counter get_obj;
    return obj;
  endfunction

  // If a copied method call loses its receiver, this same-named scope task
  // catches the defect instead of allowing the test to pass accidentally.
  task hit;
    bare_hits++;
  endtask

  pa: assert property (
        @(posedge c1) trig |-> 1'b1 ##1 @(posedge c2) 1'b1)
        repeat (2) pass_count++;
      else
        suffix_fail = -100;

  fp: assert property (
        @(posedge c1) trig |-> 1'b0 ##1 @(posedge c2) 1'b1)
        ;
      else
        for (i = 0; i < 2; i++)
          prefix_fail++;

  fs: assert property (
        @(posedge c1) trig |-> 1'b1 ##1 @(posedge c2) 1'b0)
        ;
      else
        while (suffix_fail < 3)
          suffix_fail++;

  receiver_action: assert property (
        @(posedge c1) trig |-> 1'b1 ##1 @(posedge c2) 1'b1)
        get_obj().hit();

  timed_action: assert property (
        @(posedge c1) trig |-> 1'b1 ##1 @(posedge c2) 1'b1)
        begin
          timed_started++;
          #8;
          if (!region_seen)
            region_errors++;
          timed_done++;
        end

  // The same fail statement is requested once by the c1 prefix and once by
  // the c2 suffix. Case/event and fork/repeat/delay forms used to be outside
  // the statement copier's representable subset.
  case_event_action: assert property (
        @(posedge c1) fail_trig |-> prefix_ok ##1
        @(posedge c2) suffix_ok)
        ;
      else begin
        case (mode)
          1: case_count++;
          default: case_count = -100;
        endcase
        -> action_done;
      end

  fork_action: assert property (
        @(posedge c1) fail_trig |-> prefix_ok ##1
        @(posedge c2) suffix_ok)
        ;
      else fork
        repeat (2) fork_repeat_count++;
        #1 fork_delay_count++;
      join

  // At t10 an older c2 verdict and a new c1 verdict reach each dispatcher
  // in the same time slot. This catches a request edge lost while the
  // dispatcher is already waiting for or executing the Reactive region.
  same_pass_action: assert property (
        @(posedge sc1) same_trig |-> same_prefix ##1
        @(posedge sc2) 1'b1)
        same_slot_pass++;

  same_fail_action: assert property (
        @(posedge sc1) 1'b1 |-> same_prefix ##1
        @(posedge sc2) same_suffix)
        ;
      else
        begin
          same_slot_fail++;
          #2 same_fail_done++;
        end

  always @(action_done)
    event_count++;

  initial begin
    obj = new;
    #9 trig = 1;
    #1 c1 = 1;
    #1 begin
      c1 = 0;
      trig = 0;
      prefix_ok = 1;
    end
    #9 c1 = 1;
    #1 c1 = 0;
  end

  initial begin
    #15 c2 = 1;
    #1 c2 = 0;
    #9 c2 = 1;
    #1 c2 = 0;
  end

  initial begin
    #5 sc1 = 1;              // starts one nonvacuous obligation
    #1 sc1 = 0;
    #3 begin
      same_trig = 0;         // vacuous pass at the next c1 edge
      same_prefix = 0;       // prefix failure at that same edge
    end
    #1 begin
      sc1 = 1;
      sc2 = 1;               // suffix pass/fail for the older obligations
    end
    #1 begin
      sc1 = 0;
      sc2 = 0;
    end
  end

  initial begin
    #16;
    if (timed_started != 1 || timed_done != 0) begin
      $display("FAILED -- timed checkpoint t16 start/done=%0d/%0d",
               timed_started, timed_done);
      timed_errors++;
    end
    #5;
    if (timed_started != 2 || timed_done != 0) begin
      $display("FAILED -- timed checkpoint t21 start/done=%0d/%0d",
               timed_started, timed_done);
      timed_errors++;
    end
    #3;
    if (timed_done != 1 || region_errors != 0) begin
      $display("FAILED -- timed checkpoint t24 done/region=%0d/%0d",
               timed_done, region_errors);
      timed_errors++;
    end
    #5;
    if (timed_done != 2 || region_errors != 0) begin
      $display("FAILED -- timed checkpoint t29 done/region=%0d/%0d",
               timed_done, region_errors);
      timed_errors++;
    end
  end

  // The first timed action resumes at t23. A Reactive continuation sees
  // this same-slot NBA update; an Active continuation races ahead of it.
  initial
    #23 region_seen <= 1;

  // Two failure actions are requested together at t10. Detached action
  // processes both finish at t12; a serialized dispatcher finishes the
  // second only at t14.
  initial begin
    #13;
    if (same_fail_done != 2) begin
      $display("FAILED -- same-slot delayed actions at t13=%0d",
               same_fail_done);
      timed_errors++;
    end
  end

  initial begin
    #35;
    // One nonvacuous and one vacuous pass, each executing repeat(2).
    if (pass_count != 4)
      $display("FAILED -- loop pass action count=%0d, expected 4",
               pass_count);
    else if (prefix_fail != 2)
      $display("FAILED -- for-loop prefix fail action count=%0d, expected 2",
               prefix_fail);
    else if (suffix_fail != 3)
      $display("FAILED -- while-loop suffix fail action count=%0d, expected 3",
               suffix_fail);
    else if (obj.hits != 2 || bare_hits != 0)
      $display("FAILED -- receiver method hits=%0d bare=%0d, expected 2/0",
               obj.hits, bare_hits);
    else if (timed_started != 2 || timed_done != 2 ||
             timed_errors != 0 || region_errors != 0)
      $display("FAILED -- timed action start/done/checks/region=%0d/%0d/%0d/%0d, expected 2/2/0/0",
               timed_started, timed_done, timed_errors, region_errors);
    else if (case_count != 2 || event_count != 2)
      $display("FAILED -- case/event fail actions=%0d/%0d, expected 2/2",
               case_count, event_count);
    else if (fork_repeat_count != 4 || fork_delay_count != 2)
      $display("FAILED -- fork fail actions=%0d/%0d, expected 4/2",
               fork_repeat_count, fork_delay_count);
    else if (same_slot_pass != 2 || same_slot_fail != 2 ||
             same_fail_done != 2)
      $display("FAILED -- same-slot pass/fail/done=%0d/%0d/%0d, expected 2/2/2",
               same_slot_pass, same_slot_fail, same_fail_done);
    else
      $display("PASSED");
    $finish(0);
  end
endmodule
