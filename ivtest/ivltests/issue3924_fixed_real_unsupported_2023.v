class real_array_with_dependencies;
  rand real x[2];
  rand bit arm;
  constraint ranges { foreach (x[i]) x[i] inside {[0.125:0.875]}; }
  constraint coupled { x[0] < x[1]; }
  constraint dependent { arm == (x[0] < 0.5); }
  constraint preferred { soft x[1] < 0.5; }
endclass

module test;
  real_array_with_dependencies a;
  initial begin
    a = new;
    a.srandom(3924);
    a.x[0] = 0.25;
    a.x[1] = 0.75;
    a.arm = 0;
    a.dependent.constraint_mode(0);
    a.preferred.constraint_mode(0);
    if (a.randomize()) $fatal(1, "Coupled real leaves were accepted");
    a.coupled.constraint_mode(0);
    a.dependent.constraint_mode(1);
    if (a.randomize()) $fatal(1, "Real leaf coupled to an integral variable was accepted");
    a.dependent.constraint_mode(0);
    a.preferred.constraint_mode(1);
    if (a.randomize()) $fatal(1, "Real leaf with a soft preference was accepted");
    if (a.x[0] != 0.25 || a.x[1] != 0.75 || a.arm != 0)
      $fatal(1, "Unsupported solve changed the object");
    $display("PASSED");
  end
endmodule
