// G12 tail: streaming operators with dynamically sized operands and
// targets (IEEE 1800-2017 11.4.14.1 container flattening, 11.4.14
// dynamic-target resize, 11.4.14.3 unpack, 11.4.14.4 dynamic data).
// Includes the two idioms the Accellera UVM library uses: the
// uvm_reg_map byte<->bit queue conversion pair and the uvm_misc
// string-queue join.
module g12_streaming_dynamic_test;
  typedef bit bit_q_t[$];
  int errors = 0;

  // --- the uvm_reg_map pair: byte queue -> bit queue and back -------
  initial begin
    byte p[$];
    bit bits[$];
    logic [15:0] img;
    p.push_back(8'hC7);
    p.push_back(8'h3F);

    bits = {<< 8 {bit_q_t'({<< {p}})}};
    if (bits.size() != 16) begin
      $display("FAIL t1 bits.size=%0d (expect 16)", bits.size());
      errors++;
    end
    // {<<{p}}: stream C73F bit-reversed = FCE3; {<<8{...}} byte-swaps
    // to E3FC.  bits[0] is the stream's leftmost bit.
    for (int i = 0; i < 16; i++) img[15-i] = bits[i];
    if (img !== 16'hE3FC) begin
      $display("FAIL t2 img=%h (expect E3FC)", img);
      errors++;
    end

    // exact inverse restores the byte queue
    p = {<< 8 {bit_q_t'({<< {bits}})}};
    if (p.size() != 2 || p[0] !== 8'hC7 || p[1] !== 8'h3F) begin
      $display("FAIL t3 p.size=%0d", p.size());
      errors++;
    end
  end

  // --- the uvm_misc string-queue join -------------------------------
  initial begin
    #1;
    begin
      string sq[$];
      string j;
      sq.push_back("ab");
      sq.push_back("c");
      sq.push_back("de");
      j = {>>{sq}};
      if (j != "abcde") begin
        $display("FAIL t4 j=%s (expect abcde)", j);
        errors++;
      end
    end
  end

  // --- queue/darray operands and targets ----------------------------
  initial begin
    #2;
    begin
      byte q[$];
      byte d[];
      logic [15:0] w;

      q.push_back(8'h12); q.push_back(8'h34);
      w = {>>{q}};                    // pack into fixed target
      if (w !== 16'h1234) begin $display("FAIL t5 w=%h", w); errors++; end

      q = {>>{16'hBEEF}};             // greedy resize of a queue target
      if (q.size() != 2 || q[0] !== 8'hBE || q[1] !== 8'hEF) begin
        $display("FAIL t6 q.size=%0d", q.size()); errors++;
      end

      d = {>>{16'hCAFE}};             // dynamic-array target
      if (d.size() != 2 || d[0] !== 8'hCA || d[1] !== 8'hFE) begin
        $display("FAIL t7 d.size=%0d", d.size()); errors++;
      end
      w = {>>{d}};                    // dynamic-array operand
      if (w !== 16'hCAFE) begin $display("FAIL t8 w=%h", w); errors++; end
    end
  end

  // --- unpack from a dynamic source (11.4.14.3) ---------------------
  initial begin
    #3;
    begin
      byte q[$];
      logic [7:0] a, b;
      q.push_back(8'hAA); q.push_back(8'hBB); q.push_back(8'hCC);
      {>>{a, b}} = q;        // wider source: consume from the left
      if (a !== 8'hAA || b !== 8'hBB) begin
        $display("FAIL t9 a=%h b=%h", a, b); errors++;
      end
      {<<8{a, b}} = q;       // reverse operation on the consumed bits
      if (a !== 8'hBB || b !== 8'hAA) begin
        $display("FAIL t10 a=%h b=%h", a, b); errors++;
      end
    end
  end

  // --- unpack into a queue operand ----------------------------------
  initial begin
    #4;
    begin
      byte q[$];
      {>>{q}} = 24'h010203;
      if (q.size() != 3 || q[0] !== 8'h01 || q[1] !== 8'h02
          || q[2] !== 8'h03) begin
        $display("FAIL t11 q.size=%0d", q.size()); errors++;
      end
    end
  end

  // --- mixed static/dynamic operands and empty containers -----------
  initial begin
    #5;
    begin
      byte q[$];
      byte mt[$];
      logic [23:0] w;
      q.push_back(8'h11); q.push_back(8'h22);
      w = {>>{q, 8'hFF}};
      if (w !== 24'h1122FF) begin $display("FAIL t12 w=%h", w); errors++; end
      w = {<<8{q, 8'hFF}};
      if (w !== 24'hFF2211) begin $display("FAIL t13 w=%h", w); errors++; end
      w = {>>{mt, 24'h654321}};       // empty queue contributes 0 bits
      if (w !== 24'h654321) begin $display("FAIL t14 w=%h", w); errors++; end
    end
  end

  // --- width-context r-value (the uvm_tlm2_generic_payload /
  //     uvm_unpack_intN macro shape): dynamic stream assigned to a
  //     class-property array element ----------------------------------
  class payload;
    byte m_data[];
    function void unpack_one(int i);
      bit arr[];
      arr = new[8];
      foreach (arr[k]) arr[k] = (k < 4);   // stream 1111_0000
      m_data[i] = { << bit { arr }};       // bit-reverse -> 0000_1111
    endfunction
  endclass

  initial begin
    #6;
    begin
      automatic payload pl = new;
      pl.m_data = new[2];
      pl.unpack_one(1);
      if (pl.m_data[1] !== 8'h0F) begin
        $display("FAIL t15 m_data[1]=%h (expect 0F)", pl.m_data[1]);
        errors++;
      end
    end
  end

  initial begin
    #10;
    if (errors == 0) $display("PASS");
    $finish;
  end
endmodule
