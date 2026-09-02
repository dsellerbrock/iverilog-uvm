`timescale 1ns/1ps
// IEEE 1800-2017/2023 13.5.2 and 25.9: output/inout/ref arguments of a
// task called through a scalar virtual interface belong to the physical
// interface instance selected by the current handle. Rebinding the same call
// site must change both the task body and its return-copy/ref binding.
interface vif_task_scalar_copyback_if(input int tag);
  int calls = 0;

  task automatic update(output int selected,
                        inout int accumulated,
                        ref int referenced);
    #2;
    selected = tag;
    accumulated += tag;
    referenced += tag * 100;
    calls += 1;
  endtask
endinterface

module sv_vif_task_scalar_copyback;
  int first_tag = 2;
  int second_tag = 7;
  vif_task_scalar_copyback_if first(first_tag);
  vif_task_scalar_copyback_if second(second_tag);
  virtual vif_task_scalar_copyback_if vif;

  int selected;
  int accumulated;
  int referenced;

  task automatic invoke_and_check(input int expected_tag);
    selected = -1;
    accumulated = 10;
    referenced = 1;
    fork
      begin
        #1 referenced = 3;
      end
      begin
        vif.update(selected, accumulated, referenced);
      end
    join

    if (selected != expected_tag
        || accumulated != 10 + expected_tag
        || referenced != 3 + expected_tag * 100)
      $fatal(1, "dynamic VIF task scalar copyback/ref binding failed");
  endtask

  initial begin
    vif = first;
    invoke_and_check(2);
    vif = second;
    invoke_and_check(7);

    if (first.calls != 1 || second.calls != 1)
      $fatal(1, "dynamic VIF task executed the wrong physical instance");
    $display("PASSED");
  end
endmodule
