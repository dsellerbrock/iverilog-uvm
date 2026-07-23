// M4C-8: NONBLOCKING assignment to a class property or virtual-interface
// member (`c.v <= x`, `vif.sig <= x`) must schedule the store in the NBA
// region (IEEE 1800-2017 4.9.3, 10.4.2) — formerly these silently degraded
// to BLOCKING assignments (value visible immediately, an event-region
// violation UVM drivers depend on). Now scheduled via the new
// %assign/prop/v opcode and an NBA-region scheduler event. Covers:
// immediate invisibility, last-write-wins, #delay NBA, 2-state cast,
// interleaving with plain-signal NBAs, null-handle no-op, and the clocked
// driver pattern. Residual forms (partial-select NBA) degrade with a LOUD
// codegen warning. Self-checking.
interface nba_if; logic [7:0] sig; endinterface
module sv_nba_class_property;
  class C; logic [7:0] v; bit [7:0] b; endclass
  nba_if ifc(); virtual nba_if vif;
  logic [7:0] plain;
  int e=0;
  C c0;
  initial begin
    automatic C c = new;
    vif = ifc;
    // last-write-wins ordering
    c.v = 0; c.v <= 8'h01; c.v <= 8'h02; #0;
    #1 if (c.v !== 8'h02) begin $display("F1 lww=%h", c.v); e++; end
    // NBA with delay
    c.v = 8'h00; c.v <= #2 8'h55;
    #1 if (c.v !== 8'h00) begin $display("F2 early=%h", c.v); e++; end
    #2 if (c.v !== 8'h55) begin $display("F3 late=%h", c.v); e++; end
    // 2-state property (cast path)
    c.b = 8'h00; c.b <= 8'hAA;
    if (c.b !== 8'h00) begin $display("F4 b imm=%h", c.b); e++; end
    #1 if (c.b !== 8'hAA) begin $display("F5 b nba=%h", c.b); e++; end
    // interleaved plain-signal NBA and property NBA in same slot
    plain = 8'h00; c.v = 8'h00;
    plain <= 8'h11; c.v <= 8'h22;
    if (plain !== 8'h00 || c.v !== 8'h00) begin $display("F6 interleave imm"); e++; end
    #1 if (plain !== 8'h11 || c.v !== 8'h22) begin $display("F7 interleave nba"); e++; end
    // null handle NBA: no-op, no crash
    c0.v <= 8'hFF;
    #1;
    // clocked driver pattern
    begin
      automatic int k;
      for (k=0;k<3;k++) begin
        vif.sig <= k[7:0];
        if (k>0 && vif.sig !== (k-1)) begin $display("F8 drv k=%0d sig=%h", k, vif.sig); e++; end
        #1;
      end
      if (vif.sig !== 8'h02) begin $display("F9 final=%h", vif.sig); e++; end
    end
    if (e==0) $display("PASSED"); else $display("FAILED %0d", e);
    $finish;
  end
endmodule
