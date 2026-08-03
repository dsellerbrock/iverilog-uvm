// IEEE 1800-2017 18.5.8/18.5.10: a foreach constraint set can contain a
// solve-before ordering item. OpenTitan uses this to order control fields
// ahead of selected elements in a multidimensional configuration array.
module constraint_nested_solve_before_test;
  class request;
    rand bit select;
    rand bit values[2];

    constraint ordered_c {
      foreach (values[i]) {
        solve select before values[i];
        values[i] == select;
      }
    }
  endclass

  request req;
  initial begin
    req = new();
    if (!req.randomize() || req.values[0] != req.select ||
        req.values[1] != req.select) begin
      $display("CONSTRAINT NESTED SOLVE BEFORE TEST: FAIL");
      $finish(1);
    end
    $display("CONSTRAINT NESTED SOLVE BEFORE TEST: PASS");
    $finish(0);
  end
endmodule
