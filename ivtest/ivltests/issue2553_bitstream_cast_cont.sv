// IEEE 1800-2017/2023 6.24.3 / 10.3.2: a continuous assignment of a
// bit-stream cast to a fixed-size unpacked array fills the elements left
// to right from the most significant bits, and follows its source.
module issue2553_bitstream_cast_cont;
  typedef byte b4_t[4];
  typedef logic [7:0] l4_t[3:0];
  typedef bit [3:0] n2_t[0:1];

  logic [31:0] x;
  logic [7:0] y;
  b4_t ba, ba_p;
  l4_t la, la_p;
  n2_t na;

  assign ba = b4_t'(x);
  assign la = l4_t'(x);
  assign na = n2_t'(y);
  always_comb ba_p = b4_t'(x);
  always_comb la_p = l4_t'(x);

  bit ok = 1;

  task automatic check(string what);
    if (ba !== ba_p || la !== la_p) begin
      $display("FAILED %s: ba=%h %h %h %h la=%h %h %h %h", what,
               ba[0], ba[1], ba[2], ba[3], la[3], la[2], la[1], la[0]);
      ok = 0;
    end
  endtask

  initial begin
    x = 32'h01020304; y = 8'h5a;
    #1 check("first");
    if (ba[0] !== 8'h01 || ba[3] !== 8'h04 || la[3] !== 8'h01 || la[0] !== 8'h04
        || na[0] !== 4'h5 || na[1] !== 4'ha) begin
      $display("FAILED order: %h %h %h %h", ba[0], ba[3], la[3], la[0]);
      ok = 0;
    end
    x = 32'haabbccdd; y = 8'hx3;
    #1 check("second");
    if (ba[1] !== 8'hbb || na[0] !== 4'h0 || na[1] !== 4'h3) begin
      $display("FAILED update: %h %h %h", ba[1], na[0], na[1]);
      ok = 0;
    end
    x = 32'hxx00zz11;
    #1 check("x/z");
    if (ba[0] !== 8'h00 || la[3] !== 8'hxx || la[1] !== 8'hzz) begin
      $display("FAILED x/z: %h %h %h", ba[0], la[3], la[1]);
      ok = 0;
    end
    if (ok) $display("PASSED");
  end
endmodule
