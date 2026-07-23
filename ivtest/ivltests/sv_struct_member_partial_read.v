// M4C-2/3/4: r-value selects of struct members and container-element members,
// plus the queue OOB-read-growth regression guard (IEEE 1800-2017 7.2.1,
// 7.10.2, 11.5.1). Formerly: indexed struct-member reads through class
// property chains were a NON-FATAL sorry (exit 0) evaluating to x with
// if-conditions const-folded to the wrong branch; plain unpacked-struct
// member selects silently elaborated to nil (x on assign, a blank $display
// argument, a zero compound operand); container-element member [m:l] reads
// returned 0 and [b -: w] was treated as [b +: w]; and an out-of-bounds
// queue-of-struct READ grew the queue. Self-checking.
module sv_struct_member_partial_read;
  typedef struct packed { logic [7:0] a; logic [7:0] b; } pkt_t;
  class C; pkt_t pkt; endclass
  typedef struct { bit [31:0] d; } c_t;
  typedef struct { bit [31:0] byte_en; bit [31:0] data; } bus_t;
  int errors = 0;
  initial begin
    automatic C c = new;
    automatic bus_t s;
    c_t q[$];
    c_t da[];
    c_t am[string];
    c_t x;

    // Packed-struct member selects via a class property (was non-fatal sorry).
    c.pkt = 16'hDEAD;
    if (c.pkt.b[3:0] !== 4'hD) begin $display("FAIL b[3:0]=%h", c.pkt.b[3:0]); errors++; end
    if (c.pkt.a[7:4] !== 4'hD) begin $display("FAIL a[7:4]"); errors++; end
    begin
      automatic logic [3:0] y = c.pkt.b[3:0];
      if (y !== 4'hD) begin $display("FAIL assign=%h", y); errors++; end
    end

    // Plain unpacked-struct member selects in every context (was silent nil).
    s.data = 32'h03020100;
    begin
      automatic logic [7:0] z = s.data[15:8];
      if (z !== 8'h01) begin $display("FAIL plain assign=%h", z); errors++; end
    end
    if (s.data[15 -: 8] !== 8'h01) begin $display("FAIL plain -:"); errors++; end
    for (int i = 0; i < 4; i++)
      if (s.data[i*8 +: 8] !== i[7:0]) begin $display("FAIL +: i=%0d", i); errors++; end
    begin
      automatic int sum = 0;
      for (int i = 0; i < 4; i++) sum += s.data[i*8 +: 8];
      if (sum !== 6) begin $display("FAIL compound sum=%0d", sum); errors++; end
    end
    s.byte_en = 32'h0000000D;
    if (s.byte_en[0] !== 1'b1) begin $display("FAIL disp-arg bit=%b", s.byte_en[0]); errors++; end

    // Container-element member selects (was silent 0 / -: as +:).
    x.d = 32'h0403_0201; q.push_back(x); q.push_back(x);
    da = new[2]; da[0].d = 32'hCAFE_BABE;
    am["k"].d = 32'h1234_5678;
    if (q[0].d[15:8] !== 8'h02) begin $display("FAIL q [m:l]=%h", q[0].d[15:8]); errors++; end
    if (q[0].d[15 -: 8] !== 8'h02) begin $display("FAIL q -:=%h", q[0].d[15 -: 8]); errors++; end
    if (q[0].d[8 +: 8] !== 8'h02) begin $display("FAIL q +:"); errors++; end
    for (int i = 0; i < 8; i++)
      if (q[0].d[i] !== ((32'h04030201 >> i) & 1'b1)) begin $display("FAIL q bit i=%0d", i); errors++; end
    if (da[0].d[31:16] !== 16'hCAFE) begin $display("FAIL da=%h", da[0].d[31:16]); errors++; end
    if (am["k"].d[15:0] !== 16'h5678) begin $display("FAIL am=%h", am["k"].d[15:0]); errors++; end

    // Queue OOB READ must not grow the queue (7.10.2).
    if (q[5].d !== 0) begin $display("FAIL oob val"); errors++; end
    if (q.size() !== 2) begin $display("FAIL queue GREW to %0d", q.size()); errors++; end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish;
  end
endmodule
