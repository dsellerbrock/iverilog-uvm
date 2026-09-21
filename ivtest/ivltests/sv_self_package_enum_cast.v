package p;
  typedef enum int { Wake0, Wake1, Wake2 } wakeup_e;
  `include "ivltests/sv_self_package_enum_cast_body.vh"
endpackage : p

module test;
  p::C c;

  initial begin
    c = new();
    assert (c.names[0] == "Wake0_cg") else $fatal(1, "index 0");
    assert (c.names[1] == "Wake1_cg") else $fatal(1, "index 1");
    assert (c.names[2] == "Wake2_cg") else $fatal(1, "index 2");
    assert (c.boundary_name() == "") else $fatal(1, "enum boundary");
    assert (3'(4'b1101) == 3'b101) else $fatal(1, "size cast");
    $display("PASSED");
  end
endmodule
