class legal_constraint;
  rand logic [3:0] en;
  constraint two_state_domain { en inside {[0:3]}; }
endclass

module main;
  logic [3:0] procedural;
  legal_constraint obj;
  initial begin
    procedural = 4'hx;
    obj = new;
    if (!obj.randomize()) $fatal(1, "valid two-state constraint failed");
    if (obj.en > 4'd3) $fatal(1, "constraint escaped its domain");
    if (procedural !== 4'hx) $fatal(1, "procedural X changed");
    $display("PASSED");
  end
endmodule
