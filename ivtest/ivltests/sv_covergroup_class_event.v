// Class-embedded covergroups with a declaration sampling event
// (IEEE 1800-2017 19.3): `covergroup cg @(posedge clk);` inside a
// class was a hard parse error. Instances are dynamic, so a static
// per-scope process samples every live instance of the covergroup
// class on the event, reading each instance's coverpoint source and
// iff-guard values from its parent object's properties through a
// hidden parent handle (linked when the covergroup object is stored
// into the parent's property). Also covers: instances created
// mid-simulation, per-instance guard state, coexistence with
// explicit sample() and a second covergroup, dropped handles, and
// standalone event covergroups unchanged.
module main;
  bit failed = 0;
  task check(string label, bit ok);
    if (!ok) begin
       $display("FAILED -- %0s", label);
       failed = 1;
    end
  endtask

  bit clk = 0;
  always #5 clk = ~clk;

  class C;
    bit [1:0] p;
    bit en;
    covergroup cg @(posedge clk);
      cp: coverpoint p iff (en) { bins b[] = {0,1,2,3}; }
    endgroup
    covergroup cg2;                 // explicit-sample sibling
      cp2: coverpoint p { bins b[] = {0,1,2,3}; }
    endgroup
    function new; cg = new; cg2 = new; en = 1; endfunction
  endclass

  // standalone event covergroup keeps working alongside
  bit [1:0] sv;
  covergroup sg @(posedge clk);
    cp_s: coverpoint sv { bins b[] = {0,1,2,3}; }
  endgroup
  sg s1 = new;

  C h1 = new;
  C h2 = new;
  C h3;

  initial begin
    h1.p = 0; h2.p = 3; sv = 1;
    #6;                  // posedge@5: h1<-0, h2<-3, s1<-1
    h1.p = 1; h2.en = 0; sv = 2;
    #10;                 // posedge@15: h1<-1, h2 guarded off, s1<-2
    check("event sample inst 1", h1.cg.get_inst_coverage() == 50.0);
    check("per-instance guard", h2.cg.get_inst_coverage() == 25.0);
    check("standalone alongside", s1.get_inst_coverage() == 50.0);

    h3 = new;            // created mid-simulation
    h3.p = 2;
    #10;                 // posedge@25: h3<-2
    check("mid-sim instance", h3.cg.get_inst_coverage() == 25.0);

    h1.p = 2;
    h1.cg.sample();      // explicit sample coexists: bins 0,1,2
    h1.cg2.sample();     // sibling covergroup samples only explicitly
    check("explicit + event", h1.cg.get_inst_coverage() == 75.0);
    check("sibling explicit-only", h1.cg2.get_inst_coverage() == 25.0);

    h3 = null;           // dropped handle: sampler must stay safe
    #10;
    check("h1 keeps sampling", h1.cg.get_inst_coverage() == 75.0);

    if (!failed) $display("PASSED");
    $finish(0);
  end
endmodule
