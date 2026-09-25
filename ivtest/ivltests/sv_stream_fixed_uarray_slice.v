// IEEE 1800-2017/2023 11.4.14: a fixed unpacked slice streams its
// selected elements in declared order before the << chunk reversal.
module test;
  typedef bit [23:0] packed24_t;
  class C;
    bit [7:0] payload [7:2];
    bit [7:0] ascending [2:7];
    function bit [23:0] selected();
      return {<<8{payload[6:4]}};
    endfunction
    function bit [23:0] selected_up();
      return {<<8{ascending[3 +: 3]}};
    endfunction
  endclass
  bit [7:0] down [7:2];
  bit [7:0] up [2:7];
  bit [7:0] target [0:2];
  bit [23:0] got;
  bit [31:0] wide;
  C c;
  initial begin
    c = new;
    down[7] = 'h11; down[6] = 'h22; down[5] = 'h33;
    down[4] = 'h44; down[3] = 'h55; down[2] = 'h66;
    up[2] = 'h90; up[3] = 'ha1; up[4] = 'hb2;
    up[5] = 'hc3; up[6] = 'hd4; up[7] = 'he5;
    got = {>>8{down[6:4]}};
    if (got !== 24'h223344) $fatal(1, "descending range %h", got);
    got = {<<8{down[6 -: 3]}};
    if (got !== 24'h443322) $fatal(1, "descending indexed %h", got);
    got = {>>8{down[4 +: 3]}};
    if (got !== 24'h223344) $fatal(1, "descending plus %h", got);
    got = {>>8{up[3:5]}};
    if (got !== 24'ha1b2c3) $fatal(1, "ascending range %h", got);
    got = {<<8{up[3 +: 3]}};
    if (got !== 24'hc3b2a1) $fatal(1, "ascending indexed %h", got);
    got = {>>8{up[5 -: 3]}};
    if (got !== 24'ha1b2c3) $fatal(1, "ascending minus %h", got);
    got = packed24_t'({<<8{down[6:4]}});
    if (got !== 24'h443322) $fatal(1, "cast %h", got);
    wide = {>>8{down[6:4]}};
    if (wide !== 32'h22334400) $fatal(1, "left align %h", wide);
    {>>8{target}} = {>>8{down[6:4]}};
    if (target[0] !== 'h22 || target[1] !== 'h33 ||
        target[2] !== 'h44) $fatal(1, "array target");
    c.payload[6] = 'h22; c.payload[5] = 'h33; c.payload[4] = 'h44;
    got = c.selected();
    if (got !== 24'h443322) $fatal(1, "class method property %h", got);
    got = {>>8{c.payload[6:4]}};
    if (got !== 24'h223344) $fatal(1, "class handle property %h", got);
    c.ascending[3] = 'ha1; c.ascending[4] = 'hb2;
    c.ascending[5] = 'hc3;
    got = c.selected_up();
    if (got !== 24'hc3b2a1) $fatal(1, "class method ascending %h", got);
    got = {>>8{c.ascending[3:5]}};
    if (got !== 24'ha1b2c3) $fatal(1, "class handle ascending %h", got);
    $display("PASSED");
  end
endmodule
