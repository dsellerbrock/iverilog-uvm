module p18_05_1_modscope;
  class X; rand bit [3:0] x; constraint p; extern constraint q; endclass
  constraint X::p { x < 4; }
  constraint X::q { x[0] == 1; }
  X o; int bad = 0;
  initial begin o = new; repeat (20) begin void'(o.randomize()); if (!(o.x inside {1,3})) bad++; end
    $display("MOD bad=%0d", bad); end
endmodule
