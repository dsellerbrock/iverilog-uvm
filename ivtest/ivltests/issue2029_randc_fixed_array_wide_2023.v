class item32;
  randc bit [31:0] value[2];
  constraint legal { foreach (value[i]) value[i] inside {[0:5]}; }
endclass

class item33;
  randc bit [32:0] value[2];
  constraint legal { foreach (value[i]) value[i] inside {[0:5]}; }
endclass

class item40;
  randc bit [39:0] value[2];
  constraint legal { foreach (value[i]) value[i] inside {[0:5]}; }
endclass

module test;
  initial begin
    item32 a;
    item33 b;
    item40 c;
    bit [5:0] seen32, seen33, seen40;
    a = new;
    b = new;
    c = new;
    seen32 = 0;
    seen33 = 0;
    seen40 = 0;
    repeat (6) begin
      if (!a.randomize() || !b.randomize() || !c.randomize())
        $fatal(1, "randomize failed");
      seen32[a.value[0]] = 1;
      seen33[b.value[0]] = 1;
      seen40[c.value[0]] = 1;
    end
    if (seen32 != 6'b111111 || seen33 != 6'b111111
        || seen40 != 6'b111111)
      $fatal(1, "wide randc array elements repeated: %b %b %b",
             seen32, seen33, seen40);
    $display("PASS: 32-, 33-, and 40-bit randc array elements cycle");
  end
endmodule
