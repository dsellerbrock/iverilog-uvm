class B; rand bit [3:0] v;
  constraint c1 { v < 8; }
  constraint :final cf { v[0] == 0; }
endclass
class D extends B;
  constraint :extends c1 { v > 4; }
  constraint :initial cn { v != 6; }
endclass

module p18_05_2_specifiers;
  D d;
  int bad = 0, ok = 0;
  initial begin
    d = new;
    repeat (50) begin
      ok += d.randomize();
      if (!(d.v inside {8, 10, 12, 14})) bad++;
    end
    $display("SPEC ok=%0d bad=%0d", ok, bad);
  end
endmodule
