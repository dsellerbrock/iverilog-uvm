// IEEE 1800-2023 6.6.4.1, 6.6.4.2, 28.16.2 and Syntax 22-7 (1800-2017: the
// same subclauses): charge decay of a trireg net, capacitive networks of
// trireg nets joined by tran switches, and `default_nettype trireg.

`default_nettype trireg
module dn(input d, input en);
   // imp is an implicit net, so it is a trireg of medium size.
   bufif1 (imp, d, en);
endmodule
`default_nettype wire

module top;
   integer fails = 0;

   task automatic check(input string name, input string got, input string exp);
      if (got != exp) begin
	 $display("FAILED: %s is %s, expected %s at time %0t", name, got, exp, $time);
	 fails = fails + 1;
      end
   endtask

   // ---- 28.16.2.2 Example 2: a charge decay time of 50.
   reg data, gate;
   trireg (large) #(0,0,50) cap1;
   nmos nmos1 (cap1, data, gate);

   // Decay time 0: the charge is lost at once (6.7.1 example form).
   reg d0, en0;
   trireg (small) logic #(0,0,0) cap0;
   bufif1 (cap0, d0, en0);

   // Rise and fall delays and no third delay: the charge never decays.
   reg d2, en2;
   trireg #(2,3) cap2;
   bufif1 (cap2, d2, en2);

   // A decay time that is not a constant.
   reg [7:0] dvar = 20;
   reg dq, enq;
   trireg #(0,0,dvar) capv;
   bufif1 (capv, dq, enq);

   initial begin
      data = 1; gate = 1;
      d0 = 1; en0 = 1; d2 = 0; en2 = 1; dq = 1; enq = 1;
      #1  check("cap1 driven", $sformatf("%v", cap1), "St1");
	  check("cap0 driven", $sformatf("%v", cap0), "St1");
      #9  gate = 0;		// 10: starts to hold, decay due at 60
	  en0 = 0;
	  enq = 0;		// decay due at 30
	  d2 = 1;		// rises at 12
      #1  check("cap1 at 11", $sformatf("%v", cap1), "La1");
	  check("cap0 at 11", $sformatf("%v", cap0), "SmX");
	  check("cap2 at 11", $sformatf("%v", cap2), "St0");
      #2  check("cap2 at 13", $sformatf("%v", cap2), "St1");
	  d2 = 0;		// falls at 16
      #2  check("cap2 at 15", $sformatf("%v", cap2), "St1");
      #2  check("cap2 at 17", $sformatf("%v", cap2), "St0");
	  en2 = 0;		// the drivers go off after min(2,3)
      #3  check("cap2 at 20", $sformatf("%v", cap2), "Me0");
      #9  check("capv at 29", $sformatf("%v", capv), "Me1");
      #2  check("capv at 31", $sformatf("%v", capv), "MeX");
      #9  gate = 1;		// 40: driven again, the decay is cancelled
      #5  check("cap1 at 45", $sformatf("%v", cap1), "St1");
      #5  gate = 0;		// 50: holds again, decay due at 100
      #11 check("cap1 at 61", $sformatf("%v", cap1), "La1");
      #38 check("cap1 at 99", $sformatf("%v", cap1), "La1");
      #2  check("cap1 at 101", $sformatf("%v", cap1), "LaX");
	  check("cap2 at 101", $sformatf("%v", cap2), "Me0");
   end

   // ---- Figure 6-2: a capacitive network.
   reg a, b, cv, dv;
   wire c = cv;
   wire d = dv;
   trireg (large)  trireg_la;
   trireg (small)  trireg_sm;
   trireg (medium) trireg_me1, trireg_me2;
   nmos    nmos_1    (trireg_la, c, a);
   tranif1 tranif1_1 (trireg_la, trireg_sm, b);
   nmos    nmos_2    (trireg_me1, d, a);
   tranif1 tranif1_2 (trireg_me1, trireg_me2, b);

   task automatic row(input [3:0] exp);
      if ({trireg_la, trireg_sm, trireg_me1, trireg_me2} !== exp) begin
	 $display("FAILED: Figure 6-2 at %0t: la sm me1 me2 = %b, expected %b",
		  $time, {trireg_la, trireg_sm, trireg_me1, trireg_me2}, exp);
	 fails = fails + 1;
      end
   endtask

   initial begin
      a = 1; b = 1; cv = 1; dv = 1;
      #5  row(4'b1111);
      #5  b = 0;	// 10
      #5  row(4'b1111);
      #5  cv = 0;	// 20
      #5  row(4'b0111);
      #5  dv = 0;	// 30
      #5  row(4'b0101);
      #5  a = 0;	// 40
      #5  row(4'b0101);
      #5  b = 1;	// 50: the larger wins; equal sizes go to x
      #5  row(4'b00xx);
   end

   // ---- Figure 6-3: charge sharing shows in the strength.
   reg b3, c3;
   wire a3 = 1'b1;
   trireg (large) la3;
   trireg (small) sm3;
   tranif1 t3_1 (a3, la3, b3);
   tranif1 t3_2 (la3, sm3, c3);

   // A weak driver that reaches a large charge only through a tran does
   // not win: the island resolves by strength (the standard is silent).
   reg bw;
   wire (weak0, weak1) aw = 1'b0;
   reg dl, enl;
   trireg (large) law;
   bufif1 (law, dl, enl);
   tranif1 tw (aw, law, bw);

   initial begin
      b3 = 1; c3 = 1;
      bw = 0; dl = 1; enl = 1;
      #5  check("la3 at 0", $sformatf("%v", la3), "St1");
	  check("sm3 at 0", $sformatf("%v", sm3), "St1");
	  enl = 0;
      #5  b3 = 0;	// 10
      #5  check("la3 at 10", $sformatf("%v", la3), "La1");
	  check("sm3 at 10", $sformatf("%v", sm3), "La1");
	  check("law before", $sformatf("%v", law), "La1");
	  bw = 1;
      #5  c3 = 0;	// 20
      #5  check("la3 at 20", $sformatf("%v", la3), "La1");
	  check("sm3 at 20", $sformatf("%v", sm3), "Sm1");
	  check("law against weak 0", $sformatf("%v", law), "La1");
      #5  c3 = 1;	// 30
      #5  check("la3 at 30", $sformatf("%v", la3), "La1");
	  check("sm3 at 30", $sformatf("%v", sm3), "La1");
      #5  c3 = 0;	// 40
      #5  check("la3 at 40", $sformatf("%v", la3), "La1");
	  check("sm3 at 40", $sformatf("%v", sm3), "Sm1");
   end

   // ---- `default_nettype trireg
   reg dd, den;
   dn u_dn (dd, den);
   initial begin
      dd = 1; den = 1;
      #5  den = 0;
      #5  check("implicit trireg", $sformatf("%v", u_dn.imp), "Me1");
   end

   initial begin
      #200;
      if (fails == 0)
	 $display("PASSED");
   end
endmodule
