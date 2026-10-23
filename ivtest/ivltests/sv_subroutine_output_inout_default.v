module subroutine_defaults;
  logic [7:0] a;
  logic [7:0] w;

  task t1(output logic [7:0] o = a);
    o = 42;
  endtask

  task t3(inout logic [7:0] io = w);
    io = io + 1;
  endtask
endmodule

module main;
  subroutine_defaults u();
  logic [7:0] a;
  logic [7:0] explicit_out;

  initial begin
    u.a = 1;
    u.w = 5;
    a = 99;

    u.t1();
    if (u.a !== 42 || a !== 99)
      $fatal(1, "output default was not bound in the declaring scope");

    u.t1(explicit_out);
    if (explicit_out !== 42)
      $fatal(1, "explicit output argument changed");

    u.t3();
    if (u.w !== 6)
      $fatal(1, "inout default copy-in/copy-out failed: %0d", u.w);
    u.w = 12;
    u.t3();
    if (u.w !== 13)
      $fatal(1, "inout default was not evaluated on each call: %0d", u.w);

    $display("PASS");
  end
endmodule
