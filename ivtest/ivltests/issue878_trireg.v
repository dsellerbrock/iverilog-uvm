// IEEE 1800-2023 6.6.4, 6.7.1, 28.15.2 and Table 23-1 (1800-2017: the same
// subclauses): a trireg net holds its last value at its charge strength
// when all its drivers are off, starts as x, and follows any driver that
// is not z whatever the driver strength.

// Table 23-1: an internal trireg dominates an external wire, and its
// charge size goes with it.
module p_int_trireg(t);
   inout t;
   trireg (large) t;
endmodule

// An external trireg is used with an internal wire.
module p_int_wire(inout w);
endmodule

// An internal tri0 dominates an external trireg: the net is a tri0.
module p_int_tri0(t0);
   inout t0;
   tri0 t0;
endmodule

// An external tri1 is used with an internal trireg: the net is a tri1.
module p_int_trireg2(t);
   inout t;
   trireg t;
endmodule

module top;
   integer fails = 0;

   task automatic check(input string name, input string got, input string exp);
      if (got != exp) begin
	 $display("FAILED: %s is %s, expected %s at time %0t", name, got, exp, $time);
	 fails = fails + 1;
      end
   endtask

   reg d, en;
   trireg	   t_def;	// medium by default (28.15.2)
   trireg (small)  t_sm;
   trireg (medium) t_me;
   trireg (large)  t_la;
   bufif1 (t_def, d, en);
   bufif1 (t_sm, d, en);
   bufif1 (t_me, d, en);
   bufif1 (t_la, d, en);

   // A net no driver ever touches keeps its initial x (6.7.1).
   trireg (small) t_undriven;

   // A weak driver directly on the net beats a large charge: "when at
   // least one driver has a value of 1, 0, or x, the resolved value
   // propagates into the trireg net" (6.6.4).
   reg dw, enw;
   trireg (large) t_weak;
   bufif1 (weak0, weak1) (t_weak, dw, enw);

   // Every bit of a vector is its own storage node.
   reg [3:0] dv, env;
   trireg (large) [3:0] t_vec;
   bufif1 bv [3:0] (t_vec, dv, env);

   // Figure 6-1: the driver of d6 goes to HiZ behind two nmos switches.
   reg a6, b6;
   wire src6 = 1'b1;
   wire c6;
   trireg d6;
   nmos (c6, src6, a6);
   nmos (d6, c6, b6);

   // Table 23-1.
   reg pd, pen;
   wire ext_wire;
   trireg (small) ext_trireg;
   trireg (large) ext_trireg0;
   tri1 ext_tri1;
   bufif1 (ext_wire, pd, pen);
   bufif1 (ext_trireg, pd, pen);
   bufif1 (ext_trireg0, pd, pen);
   bufif1 (ext_tri1, pd, pen);
   p_int_trireg  u1 (ext_wire);
   p_int_wire    u2 (ext_trireg);
   p_int_tri0    u3 (ext_trireg0);
   p_int_trireg2 u4 (ext_tri1);

   initial begin
      // 6.7.1: x at the charge strength before anything drives the net.
      en = 0; enw = 0; env = 4'b0000; a6 = 0; b6 = 0; pen = 0;
      d = 0; dw = 0; dv = 0; pd = 0;
      #1;
      check("t_def initial", $sformatf("%v", t_def), "MeX");
      check("t_sm initial", $sformatf("%v", t_sm), "SmX");
      check("t_la initial", $sformatf("%v", t_la), "LaX");
      check("t_undriven", $sformatf("%v", t_undriven), "SmX");

      // Driven state shows the strength of the driver.
      d = 1; en = 1;
      #1;
      check("t_def driven", $sformatf("%v", t_def), "St1");
      check("t_la driven", $sformatf("%v", t_la), "St1");

      // Capacitive state: the last value at the charge strength.
      en = 0;
      #1;
      check("t_def hold 1", $sformatf("%v", t_def), "Me1");
      check("t_sm hold 1", $sformatf("%v", t_sm), "Sm1");
      check("t_me hold 1", $sformatf("%v", t_me), "Me1");
      check("t_la hold 1", $sformatf("%v", t_la), "La1");
      // The input of a disabled driver does not get through.
      d = 0;
      #1;
      check("t_sm still 1", $sformatf("%v", t_sm), "Sm1");
      en = 1;
      #1;
      check("t_sm driven 0", $sformatf("%v", t_sm), "St0");
      en = 0;
      #1;
      check("t_def hold 0", $sformatf("%v", t_def), "Me0");
      check("t_sm hold 0", $sformatf("%v", t_sm), "Sm0");
      check("t_la hold 0", $sformatf("%v", t_la), "La0");
      if (t_undriven !== 1'bx) begin
	 $display("FAILED: t_undriven is %b", t_undriven);
	 fails = fails + 1;
      end

      // A weak driver against a large charge of the other value.
      dw = 1; enw = 1;
      #1;
      check("t_weak driven 1", $sformatf("%v", t_weak), "We1");
      enw = 0;
      #1;
      check("t_weak hold 1", $sformatf("%v", t_weak), "La1");
      dw = 0; enw = 1;
      #1;
      check("t_weak driven 0", $sformatf("%v", t_weak), "We0");
      enw = 0;
      #1;
      check("t_weak hold 0", $sformatf("%v", t_weak), "La0");

      // Vector: release the two high bits, then change the data.
      dv = 4'b1010; env = 4'b1111;
      #1;
      env = 4'b0011;
      #1;
      dv = 4'b0101;
      #1;
      if (t_vec !== 4'b1001) begin
	 $display("FAILED: t_vec is %b, expected 1001", t_vec);
	 fails = fails + 1;
      end
      check("t_vec[3]", $sformatf("%v", t_vec[3]), "La1");
      check("t_vec[2]", $sformatf("%v", t_vec[2]), "La0");
      check("t_vec[0]", $sformatf("%v", t_vec[0]), "St1");

      // Figure 6-1.
      a6 = 1; b6 = 1;
      #1;
      check("d6 at 0", $sformatf("%v", d6), "St1");
      a6 = 0;
      #1;
      check("c6 at 10", $sformatf("%v", c6), "HiZ");
      check("d6 at 10", $sformatf("%v", d6), "Me1");

      // Table 23-1.
      pd = 1; pen = 1;
      #1;
      pen = 0;
      #1;
      check("internal trireg, external wire", $sformatf("%v", ext_wire), "La1");
      check("internal wire, external trireg", $sformatf("%v", ext_trireg), "Sm1");
      check("internal tri0, external trireg", $sformatf("%v", ext_trireg0), "Pu0");
      check("internal trireg, external tri1", $sformatf("%v", ext_tri1), "Pu1");
      pd = 0; pen = 1;
      #1;
      pen = 0;
      #1;
      check("internal trireg, external wire 0", $sformatf("%v", ext_wire), "La0");
      check("internal trireg, external tri1 0", $sformatf("%v", ext_tri1), "Pu1");

      if (fails == 0)
	 $display("PASSED");
   end
endmodule
