// IEEE 1800-2017 6.17 and 6.21: an explicit static declaration inside an
// automatic task has one shared synchronization identity across concurrent
// activations. A declaration with no override still inherits automatic
// lifetime and therefore keeps a distinct identity in each activation.
module sv_automatic_task_static_event;
  int static_wakes;
  int inherited_wakes;

  task automatic use_static_event(input bit wait_side);
    static event sync;
    if (wait_side) begin
      @sync;
      static_wakes++;
    end else begin
      #1 -> sync;
    end
  endtask

  task automatic use_inherited_event(input bit wait_side);
    event sync;
    if (wait_side) begin
      @sync;
      inherited_wakes++;
    end else begin
      #1 -> sync;
    end
  endtask

  initial begin
    fork
      use_static_event(1'b1);
      use_static_event(1'b0);
      use_inherited_event(1'b1);
      use_inherited_event(1'b0);
    join_none

    #5;
    if (static_wakes == 1 && inherited_wakes == 0)
      $display("PASSED");
    else
      $display("FAILED static_wakes=%0d inherited_wakes=%0d",
               static_wakes, inherited_wakes);
    $finish(0);
  end
endmodule
