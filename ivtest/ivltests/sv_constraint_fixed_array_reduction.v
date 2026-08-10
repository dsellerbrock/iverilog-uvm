// IEEE 1800-2017 18.5.8.2: fixed-array reductions in class constraints are
// exact solver expressions over every rand element. The method result remains
// self-determined at the element width before a wider comparison context.
class fixed_reduction_constraints;
  rand bit [3:0] values[0:3];
  rand bit [3:0] factors[-1:0];
  constraint total_c { values.sum() == 10; }
  constraint product_c { factors.product() == 4'd6; }
endclass

class impossible_reduction_width;
  rand bit [3:0] values[0:1];
  // A 4-bit sum is truncated before comparison with the unsized 32-bit 16.
  constraint impossible_c { values.sum() == 16; }
endclass

class fixed_reduction_state_constraint;
  bit [7:0] state_values[3:4];
  rand bit [7:0] solved_value;
  constraint state_c { solved_value == state_values.sum(); }
endclass

class fixed_reduction_with_constraint;
  rand bit signed [3:0] values[-2:0];
  constraint elements_c {
    values[-2] == 4'sd1;
    values[-1] == 4'sd2;
    values[0] == 4'sd3;
  }
  // The with expression is 32 bits because index() is a signed int. Its
  // declared indices are -2, -1 and 0 even though the solver stores elements
  // in canonical slots 0, 1 and 2: 1*-2 + 2*-1 + 3*0 == -4.
  constraint reduction_c {
    values.sum(value) with (value * value.index()) == -32'sd4;
  }
endclass

module main;
  fixed_reduction_constraints good;
  impossible_reduction_width impossible;
  fixed_reduction_state_constraint state_control;
  fixed_reduction_with_constraint with_control;
  bit failed;
  int iteration;

  task automatic check(input string label, input logic ok);
    if (ok !== 1'b1) begin
      $display("FAILED -- %0s", label);
      failed = 1'b1;
    end
  endtask

  initial begin
    failed = 1'b0;
    good = new;
    impossible = new;
    state_control = new;
    with_control = new;
    for (iteration = 0; iteration < 8; iteration = iteration + 1) begin
      check("satisfiable reduction constraints", good.randomize() == 1);
      check("sum constraint applied", good.values.sum() == 4'd10);
      check("product constraint applied", good.factors.product() == 4'd6);
    end
    check("self-determined width makes impossible constraint UNSAT",
          impossible.randomize() == 0);

    state_control.state_values[3] = 8'd200;
    state_control.state_values[4] = 8'd100;
    check("state-array reduction constraint is satisfiable",
          state_control.randomize() == 1);
    check("non-rand reduction leaves are pinned",
          state_control.solved_value == 8'd44);
    check("solver does not rewrite non-rand array state",
          state_control.state_values[3] == 8'd200
          && state_control.state_values[4] == 8'd100);

    check("with reduction constraint is satisfiable",
          with_control.randomize() == 1);
    check("with reduction uses declared nonzero indices",
          with_control.values.sum(value)
            with (value * value.index()) == -32'sd4);

    if (failed)
      $fatal(1, "fixed-array reduction constraint checks failed");
    $display("PASSED");
  end
endmodule
