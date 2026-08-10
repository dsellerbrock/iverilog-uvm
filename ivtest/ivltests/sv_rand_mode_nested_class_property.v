// A field rand_mode call whose object is itself a class property must keep
// the complete receiver expression.  In particular, inside controller::run
// the prefix `first' resolves as this.first, not as the controller object.
class random_item;
  rand int value;
  randc bit [7:0] cycle;
  static rand int shared;

  constraint bounds {
    value inside {[1:10]};
    cycle inside {[1:10]};
    shared inside {[1:10]};
  }
endclass

class controller;
  random_item first = new;
  random_item second = new;

  task run;
    int status;

    first.value = 7;
    first.value.rand_mode(0);
    if (first.value.rand_mode() !== 0)
      $fatal(1, "nested rand field did not disable");
    status = first.randomize();
    if (status !== 1 || first.value !== 7)
      $fatal(1, "disabled nested rand field changed");
    first.value.rand_mode(1);
    if (first.value.rand_mode() !== 1)
      $fatal(1, "nested rand field did not re-enable");

    first.cycle.rand_mode(0);
    if (first.cycle.rand_mode() !== 0)
      $fatal(1, "nested randc field did not disable");
    first.cycle.rand_mode(1);

    first.shared.rand_mode(0);
    if (first.shared.rand_mode() !== 0 || second.shared.rand_mode() !== 0)
      $fatal(1, "static rand mode was not shared across instances");
    second.shared.rand_mode(1);
    if (first.shared.rand_mode() !== 1)
      $fatal(1, "static rand mode did not re-enable across instances");
  endtask
endclass

module test;
  initial begin
    controller c;
    c = new;
    c.run();
    $display("PASSED");
  end
endmodule
