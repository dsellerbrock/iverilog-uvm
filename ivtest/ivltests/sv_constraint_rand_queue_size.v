// IEEE 1800-2017 18.4/18.5.8.2: a rand queue's size is solved before its
// iterative element constraints. Cover real queue construction, grow/shrink,
// the declared bound, and transactional rollback when the element pass is
// UNSAT after the size pass has already resized the live queue.
module main;
  class queue_sat;
    rand byte unsigned values[$];
    int unsigned wanted_size;
    constraint c_size {
      values.size() == wanted_size;
    }
    constraint c_values {
      foreach (values[i]) values[i] == 8'h20 + i;
    }
  endclass

  class queue_bounded;
    rand byte unsigned values[$:2];
    constraint c_size {
      values.size() == 4;
    }
  endclass

  class queue_rollback;
    rand byte unsigned values[$];
    constraint c_size {
      values.size() == 2;
    }
    constraint c_impossible_elements {
      foreach (values[i]) {
        values[i] == i;
        values[i] > 10;
      }
    }
  endclass

  int errors = 0;

  task automatic check(input string label, input bit ok);
    if (!ok) begin
      $display("FAILED -- %0s", label);
      errors++;
    end
  endtask

  initial begin
    automatic queue_sat sat = new;
    automatic queue_bounded bounded = new;
    automatic queue_rollback rollback = new;
    int ok;

    sat.values.push_back(8'hee);
    sat.wanted_size = 3;
    ok = sat.randomize();
    check("SAT grow", ok && sat.values.size() == 3);
    check("SAT grow values", sat.values.size() == 3
          && sat.values[0] == 8'h20 && sat.values[1] == 8'h21
          && sat.values[2] == 8'h22);

    sat.wanted_size = 1;
    ok = sat.randomize();
    check("SAT shrink", ok && sat.values.size() == 1
          && sat.values[0] == 8'h20);

    bounded.values.push_back(8'h41);
    bounded.values.push_back(8'h42);
    ok = bounded.randomize();
    check("bounded UNSAT", !ok);
    check("bounded preserve", bounded.values.size() == 2
          && bounded.values[0] == 8'h41 && bounded.values[1] == 8'h42);

    rollback.values.push_back(8'h51);
    rollback.values.push_back(8'h52);
    rollback.values.push_back(8'h53);
    ok = rollback.randomize();
    check("element-pass UNSAT", !ok);
    check("element-pass rollback", rollback.values.size() == 3
          && rollback.values[0] == 8'h51
          && rollback.values[1] == 8'h52
          && rollback.values[2] == 8'h53);

    if (errors == 0)
      $display("PASSED");
    else
      $display("FAILED -- %0d errors", errors);
  end
endmodule
