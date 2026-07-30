// Packed struct properties of classes and virtual interfaces:
// array-of-struct member hops and VARIABLE indices, reads and writes
// (recovery C4 wave 3). Pre-fix: constant-index writes through an
// array-of-struct hop (c.reg2hw.key[0].qe = v) and every variable
// index were loud sorries; reads through the hop errored.
typedef struct packed { logic q; logic qe; } key_field_t;
typedef struct packed { key_field_t [3:0] key; logic [1:0] tag; } reg2hw_t;
typedef struct packed { logic [7:0] fld; logic [3:0] pad; } s_t;

interface bus_if;
  // Typedefs local to the interface: resolving an interface property
  // type from $unit is a separate, pre-existing gap.
  typedef struct packed { logic q; logic qe; } if_key_t;
  typedef struct packed { if_key_t [3:0] key; logic [1:0] tag; } if_reg2hw_t;
  if_reg2hw_t reg2hw;
endinterface

module main;
  class C;
    reg2hw_t reg2hw;
    s_t data;
  endclass

  C c;
  bus_if pif();
  virtual bus_if vif;
  int i, fails = 0;

  initial begin
    c = new;
    vif = pif;

    // constant array-of-struct hop writes (were loud sorries)
    c.reg2hw = '0;
    c.reg2hw.tag = 2'h3;
    c.reg2hw.key[0].qe = 1'b0;
    c.reg2hw.key[1].qe = 1'b1;
    c.reg2hw.key[2].qe = 1'b0;
    c.reg2hw.key[3].qe = 1'b1;
    // variable-index reads through the hop
    for (i = 0; i < 4; i++)
      if (c.reg2hw.key[i].qe !== i[0]) begin
        fails++; $display("FAILED: key[%0d].qe=%b", i, c.reg2hw.key[i].qe);
      end
    if (c.reg2hw.tag !== 2'h3) begin fails++; $display("FAILED: tag=%h", c.reg2hw.tag); end

    // variable-index WRITES through the hop
    for (i = 0; i < 4; i++) c.reg2hw.key[i].q = ~i[0];
    for (i = 0; i < 4; i++)
      if (c.reg2hw.key[i].q !== ~i[0]) begin
        fails++; $display("FAILED: key[%0d].q=%b", i, c.reg2hw.key[i].q);
      end
    // siblings intact
    for (i = 0; i < 4; i++)
      if (c.reg2hw.key[i].qe !== i[0]) begin
        fails++; $display("FAILED: sibling key[%0d].qe=%b", i, c.reg2hw.key[i].qe);
      end

    // variable bit index on a vector property field, write + read
    c.data = '0;
    c.data.pad = 4'hC;
    for (i = 0; i < 8; i++) c.data.fld[i] = i[0];
    if (c.data.fld !== 8'b10101010) begin fails++; $display("FAILED: fld=%b", c.data.fld); end
    if (c.data.pad !== 4'hC) begin fails++; $display("FAILED: pad=%h", c.data.pad); end

    // variable-base indexed part-select read on the field
    i = 3;
    if (c.data.fld[i +: 2] !== 2'b01) begin
      fails++; $display("FAILED: fld[i+:2]=%b", c.data.fld[i +: 2]);
    end

    // same shapes through a virtual interface
    vif.reg2hw = '0;
    vif.reg2hw.key[2].qe = 1'b1;
    for (i = 0; i < 4; i++)
      if (vif.reg2hw.key[i].qe !== (i == 2)) begin
        fails++; $display("FAILED: vif key[%0d].qe=%b", i, vif.reg2hw.key[i].qe);
      end
    for (i = 0; i < 4; i++) vif.reg2hw.key[i].q = i[0];
    for (i = 0; i < 4; i++)
      if (vif.reg2hw.key[i].q !== i[0]) begin
        fails++; $display("FAILED: vif key[%0d].q=%b", i, vif.reg2hw.key[i].q);
      end

    if (fails == 0) $display("PASSED");
    else $display("FAILED count=%0d", fails);
  end
endmodule
