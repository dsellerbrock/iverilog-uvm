// M4B-8: partial write into a struct field reached through a VIRTUAL INTERFACE.
// An interface-local typedef'd struct member (`vif.pkt.a`, `vif.pkt.b[3:0]`)
// was silently miscompiled: the interface-local typedef failed to resolve when
// the virtual-interface property type was elaborated (a disposable scope
// carried only parameters, not typedefs), so the member degraded to a 32-bit
// integer and the sub-field write was dropped or clobbered the whole field.
// Also covers the same packed-struct-field part-select through a class
// property, which shared the defect. IEEE 1800-2017 25.9 (virtual interfaces),
// 7.2.1 (packed struct member). Self-checking.
interface m4b8_if;
  typedef struct packed { logic [7:0] a, b; } pkt_t;
  pkt_t pkt;
  logic [15:0] flat;
endinterface

module sv_vif_struct_field_write;
  typedef struct packed { logic [7:0] a, b; } cpkt_t;
  class C; cpkt_t pkt; endclass

  m4b8_if ifc();
  virtual m4b8_if vif;
  int errors = 0;

  initial begin
    automatic C c = new;
    vif = ifc;

    // Whole struct sub-field write through a vif.
    vif.pkt = 16'h1234;
    vif.pkt.a = 8'hCD;
    if (vif.pkt !== 16'hCD34) begin $display("FAIL vif a: %h exp cd34", vif.pkt); errors++; end

    // Part-select of a struct sub-field through a vif.
    vif.pkt.b[3:0] = 4'hF;
    if (vif.pkt !== 16'hCD3F) begin $display("FAIL vif b[3:0]: %h exp cd3f", vif.pkt); errors++; end

    // Single-bit select of a struct sub-field through a vif.
    vif.pkt.a[0] = 1'b0;
    if (vif.pkt !== 16'hCC3F) begin $display("FAIL vif a[0]: %h exp cc3f", vif.pkt); errors++; end

    // Plain vector part-select through a vif (control).
    vif.flat = 16'hFFFF; vif.flat[7:0] = 8'h00;
    if (vif.flat !== 16'hFF00) begin $display("FAIL vif flat: %h exp ff00", vif.flat); errors++; end

    // Same packed-struct-field part-select through a class property.
    c.pkt = 16'h1234;
    c.pkt.a = 8'hCD;
    c.pkt.b[3:0] = 4'hF;
    c.pkt.a[7] = 1'b0;
    if (c.pkt !== 16'h4D3F) begin $display("FAIL class: %h exp 4d3f", c.pkt); errors++; end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish;
  end
endmodule
