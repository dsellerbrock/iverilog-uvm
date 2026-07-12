// G12: streaming concatenation with multiple operands, both as an
// expression (pack) and as an assignment target (unpack).
// IEEE 1800-2017 11.4.14 (operators), 11.4.14.1 (stream build),
// 11.4.14.2 (re-ordering), 11.4.14.3 (unpack).
// Every literal example from 11.4.14.2/.3 that fits fixed-size
// integral operands is checked here.
module g12_streaming_concat_test;
  int errors = 0;

  // --- multi-operand unpack, stream order (>>) --------------------
  logic [7:0] a, b, c, d;
  initial begin
    {>>{a, b, c, d}} = 32'hAABBCCDD;
    if (a !== 8'hAA || b !== 8'hBB || c !== 8'hCC || d !== 8'hDD) begin
      $display("FAIL t1 >> unpack: %h %h %h %h", a, b, c, d);
      errors++;
    end

    // --- multi-operand unpack with byte reversal (<<8) ------------
    {<< 8 {a, b, c, d}} = 32'hAABBCCDD;
    if (a !== 8'hDD || b !== 8'hCC || c !== 8'hBB || d !== 8'hAA) begin
      $display("FAIL t2 <<8 unpack: %h %h %h %h", a, b, c, d);
      errors++;
    end

    // --- multi-operand pack ---------------------------------------
    a = 8'hAA; b = 8'hBB; c = 8'hCC; d = 8'hDD;
    begin
      logic [31:0] y;
      y = {>>{a, b, c, d}};
      if (y !== 32'hAABBCCDD) begin
        $display("FAIL t3 >> pack: %h", y);
        errors++;
      end
      y = {<< 8 {a, b, c, d}};
      if (y !== 32'hDDCCBBAA) begin
        $display("FAIL t4 <<8 pack: %h", y);
        errors++;
      end
    end
  end

  // --- LRM 11.4.14.2 literal examples ------------------------------
  initial begin
    #1;
    begin
      logic [7:0] s8;
      logic [5:0] s6;
      logic [3:0] s4;
      s8 = {<< { 8'b0011_0101 }};
      if (s8 !== 8'b1010_1100) begin
        $display("FAIL t5 bit reverse: %b", s8);
        errors++;
      end
      s6 = {<< 4 { 6'b11_0101 }};
      if (s6 !== 6'b0101_11) begin
        $display("FAIL t6 <<4 remainder pack: %b", s6);
        errors++;
      end
      s6 = {>> 4 { 6'b11_0101 }};
      if (s6 !== 6'b1101_01) begin
        $display("FAIL t7 >>4 pack: %b", s6);
        errors++;
      end
      s4 = {<< 2 { { << { 4'b1101 }} }};
      if (s4 !== 4'b1110) begin
        $display("FAIL t8 nested streams: %b", s4);
        errors++;
      end
    end
  end

  // --- unpack is the reverse of pack (11.4.14.3), including a
  //     slice that does not divide the width ------------------------
  logic [19:0] x20;
  initial begin
    #2;
    x20 = 20'hABCDE;
    begin
      logic [19:0] y20;
      y20 = {<<8{x20}};
      if (y20 !== 20'hDEBCA) begin
        $display("FAIL t9 <<8 remainder pack: %h", y20);
        errors++;
      end
      {<<8{x20}} = y20;              // must round-trip
      if (x20 !== 20'hABCDE) begin
        $display("FAIL t10 <<8 remainder unpack (round-trip): %h", x20);
        errors++;
      end
    end
  end

  // --- wider source: consume from the left (11.4.14.3 example:
  //     "hello world" → a="hell", b="o wo", rest ignored) -----------
  initial begin
    #3;
    begin
      int ia, ib;
      automatic logic [87:0] s = "hello world";
      {>>{ia, ib}} = s;
      if (ia !== "hell" || ib !== "o wo") begin
        $display("FAIL t11 wider-source unpack: %s %s", ia, ib);
        errors++;
      end
    end
  end

  // --- pack as assignment source is left-aligned (11.4.14 example:
  //     bit [99:0] d = {>>{a,b,c}} pads 4 bits on the right) --------
  initial begin
    #4;
    begin
      automatic bit [7:0] pa = 8'hAA, pb = 8'hBB, pc = 8'hCC;
      bit [99:0] wide;
      wide = {>>{pa, pb, pc}};
      if (wide[99:76] !== 24'hAABBCC || wide[75:0] !== 0) begin
        $display("FAIL t12 pack left-align: %h", wide);
        errors++;
      end
    end
  end

  // --- typed slice and parameter slice ----------------------------
  localparam int SL = 16;
  initial begin
    #5;
    begin
      logic [31:0] t;
      t = {<< byte {32'h11223344}};
      if (t !== 32'h44332211) begin
        $display("FAIL t13 typed slice: %h", t);
        errors++;
      end
      t = {<< SL {32'hCAFE_F00D}};
      if (t !== 32'hF00D_CAFE) begin
        $display("FAIL t14 parameter slice: %h", t);
        errors++;
      end
    end
  end

  // --- nonblocking streaming assignment target ---------------------
  logic [7:0] na, nb, nc, nd;
  initial begin
    #6;
    {>>{na, nb, nc, nd}} <= 32'h55667788;
    #1;
    if (na !== 8'h55 || nb !== 8'h66 || nc !== 8'h77 || nd !== 8'h88) begin
      $display("FAIL t15 nonblocking unpack: %h %h %h %h", na, nb, nc, nd);
      errors++;
    end
  end

  initial begin
    #10;
    if (errors == 0) $display("PASS");
    $finish;
  end
endmodule
