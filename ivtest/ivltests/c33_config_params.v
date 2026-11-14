// IEEE 1800-2023 33.4.3: setting parameters in configurations, examples 3
// to 8. Each config has its own design cell, so all five are selected and
// all five cells are top-level cells (33.5.4).
int errors = 0;

function automatic void check(string inst, logic [15:0] id, logic [15:0] exp_id,
			      int w, int exp_w, int d, int exp_d);
   if (id !== exp_id || w !== exp_w || d !== exp_d) begin
      $display("FAILED: %s: ID = %s, W = %0d, D = %0d", inst, id, w, d);
      errors++;
   end
endfunction

module adder #(parameter ID = "id", W = 8, D = 512) ();
endmodule

// Examples 2 and 3: override a parameter of the top-level cell and pass it
// on with a hierarchical name.
module top;
   parameter WIDTH = 16;
   adder a1();
   initial #1 check("top.a1", a1.ID, "id", a1.W, 32, a1.D, 512);
endmodule

config cfg1;
   design top;
   instance top use #(.WIDTH(32));
   instance top.a1 use #(.W(top.WIDTH));
endconfig

// Example 4: S alone is the localparam of the config, top4.S the parameter
// of the module. (a4 is not in the standard: a localparam in an expression.)
module top4;
   parameter S = 16;
   adder #(.ID("a1")) a1();
   adder #(.ID("a2")) a2();
   adder #(.ID("a3")) a3();
   adder #(.ID("a4")) a4();
   initial begin
      #1;
      check("top4.a1", a1.ID, "a1", a1.W, 16, a1.D, 512);
      check("top4.a2", a2.ID, "a2", a2.W, 24, a2.D, 512);
      check("top4.a3", a3.ID, "a3", a3.W, 8, a3.D, 512);
      check("top4.a4", a4.ID, "a4", a4.W, 25, a4.D, 512);
   end
endmodule

config cfg2;
   localparam S = 24;
   design top4;
   instance top4.a1 use #(.W(top4.S));
   instance top4.a2 use #(.W(S));
   instance top4.a4 use #(.W(S + 1));
endconfig

// Examples 5 and 6: empty parentheses set one parameter back to its default.
module top5;
   parameter WIDTH = 64, DEPTH = 1024, ID = "A1";
   adder #(.ID(ID), .W(WIDTH), .D(DEPTH)) a1();
   initial #1 check("top5.a1", a1.ID, "A1", a1.W, 8, a1.D, 1024);
endmodule

config cfg3;
   design top5;
   instance top5.a1 use #(.W()); // set only parameter W back to its default
endconfig

// Example 7: #() sets all the parameters back to their defaults.
module top7;
   adder #(.ID("a7"), .W(4), .D(4)) a1();
   initial #1 check("top7.a1", a1.ID, "id", a1.W, 8, a1.D, 512);
endmodule

config cfg4;
   design top7;
   instance top7.a1 use #();
endconfig

// Example 8: the config takes precedence over the defparam for t.WIDTH;
// the defparam for t.a1.W works as usual.
module test;
   top8 t();
   defparam t.WIDTH = 64;
   defparam t.a1.W = 16;
   initial begin
      #1;
      check("test.t.a1", t.a1.ID, "a1", t.a1.W, 16, t.a1.D, 512);
      check("test.t.a2", t.a2.ID, "a2", t.a2.W, 48, t.a2.D, 512);
      #1;
      if (errors == 0) $display("PASSED");
   end
endmodule

module top8;
   parameter WIDTH = 32;
   adder #(.ID("a1")) a1();
   adder #(.ID("a2"), .W(WIDTH)) a2();
endmodule

config cfg6;
   design test;
   instance test.t use #(.WIDTH(48));
endconfig
