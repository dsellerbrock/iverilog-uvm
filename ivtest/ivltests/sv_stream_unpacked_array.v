// Streaming to and from FIXED unpacked arrays (IEEE 1800-2017
// 11.4.14.3) — both were loud rejects: `{>>byte{arr}} = word` failed
// the implicit-cast check and `{>>byte{arr}}` as an r-value errored
// "needs an array index". Class-property array operands packed
// silently wrong. Dynamic (darray/queue) targets already worked.
module main;
  bit failed = 0;
  task check(string label, bit ok);
    if (!ok) begin
       $display("FAILED -- %0s", label);
       failed = 1;
    end
  endtask

  bit [7:0] arr [4];
  bit [7:0] darr [3:0];
  bit [7:0] dst [4];
  bit [7:0] dyn [];
  bit [7:0] q [$];
  bit [31:0] word = 32'hAABBCCDD;

  class C;
    bit [7:0] payload [4];
  endclass

  initial begin
    automatic C c = new;
    automatic bit [31:0] back;

    // unpack, MSB first
    { >> byte {arr}} = word;
    check("rshift unpack", arr[0] == 8'hAA && arr[1] == 8'hBB
          && arr[2] == 8'hCC && arr[3] == 8'hDD);

    // pack back
    back = { >> byte {arr}};
    check("rshift pack", back == 32'hAABBCCDD);
    check("lshift pack", { << byte {arr}} == 32'hDDCCBBAA);

    // << unpack: byte-reversed
    { << byte {arr}} = word;
    check("lshift unpack", arr[0] == 8'hDD && arr[3] == 8'hAA);

    // descending declared range fills its LEFT bound first
    { >> byte {darr}} = word;
    check("descending", darr[3] == 8'hAA && darr[0] == 8'hDD);

    // array-to-array streaming copy
    arr[0] = 8'h11; arr[1] = 8'h22; arr[2] = 8'h33; arr[3] = 8'h44;
    { >> byte {dst}} = { >> byte {arr}};
    check("arr to arr", dst[0] == 8'h11 && dst[3] == 8'h44);

    // wider source: leading (left-most) bits are consumed
    begin
      automatic bit [7:0] two [2];
      { >> byte {two}} = word;
      check("wide source", two[0] == 8'hAA && two[1] == 8'hBB);
    end

    // class-property array, both directions
    { >> byte {c.payload}} = word;
    check("prop unpack", c.payload[0] == 8'hAA && c.payload[3] == 8'hDD);
    back = { >> byte {c.payload}};
    check("prop pack", back == 32'hAABBCCDD);

    // dynamic targets keep working, with values
    { >> byte {dyn}} = word;
    check("dyn", dyn.size() == 4 && dyn[0] == 8'hAA && dyn[3] == 8'hDD);
    { << byte {q}} = word;
    check("queue", q.size() == 4 && q[0] == 8'hDD && q[3] == 8'hAA);

    if (!failed) $display("PASSED");
  end
endmodule
