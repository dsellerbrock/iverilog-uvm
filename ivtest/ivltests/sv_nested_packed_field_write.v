// Nested packed-struct field writes through a class property and a
// virtual-interface-style handle: c.data.inner.sub = v must write ONLY
// the sub-field's bits. Pre-fix (recovery C4-a6) the walker consumed a
// single member hop and wrote the WHOLE outer field with only a
// warning: c.data.inner.sub = 4'hA stored 8'h0A over all of `inner',
// silently zeroing the sibling and reading sub back as 0.
typedef struct packed {
  logic [3:0] sub;
  logic [3:0] other;
} inner_t;

typedef struct packed {
  inner_t inner;
  logic flag;
} outer_t;

typedef struct packed {
  outer_t o;
  logic [2:0] tag;
} outer2_t;

module main;
  class C;
    outer_t data;
    outer2_t deep;
  endclass

  C c;
  int fails = 0;

  initial begin
    c = new;

    // two-level: write both subfields and the flag, check integrity
    c.data.inner.sub   = 4'hA;
    c.data.inner.other = 4'h5;
    c.data.flag        = 1'b1;
    if (c.data.inner.sub   !== 4'hA) begin fails++; $display("FAILED: sub=%h", c.data.inner.sub); end
    if (c.data.inner.other !== 4'h5) begin fails++; $display("FAILED: other=%h", c.data.inner.other); end
    if (c.data.flag        !== 1'b1) begin fails++; $display("FAILED: flag=%b", c.data.flag); end

    // overwrite one subfield; siblings must hold
    c.data.inner.sub = 4'h3;
    if (c.data.inner.other !== 4'h5 || c.data.flag !== 1'b1) begin
      fails++; $display("FAILED: sibling clobber other=%h flag=%b", c.data.inner.other, c.data.flag);
    end

    // three-level nesting
    c.deep.o.inner.sub   = 4'h7;
    c.deep.o.inner.other = 4'h2;
    c.deep.o.flag        = 1'b0;
    c.deep.tag           = 3'h5;
    if (c.deep.o.inner.sub !== 4'h7 || c.deep.o.inner.other !== 4'h2
        || c.deep.tag !== 3'h5) begin
      fails++; $display("FAILED: deep %h %h %h", c.deep.o.inner.sub, c.deep.o.inner.other, c.deep.tag);
    end

    // whole-field write still works beside the nested form
    c.data.inner = 8'h5A;
    if (c.data.inner.sub !== 4'h5 || c.data.inner.other !== 4'hA) begin
      fails++; $display("FAILED: whole field %h", c.data.inner);
    end

    if (fails == 0) $display("PASSED");
    else $display("FAILED count=%0d", fails);
  end
endmodule
