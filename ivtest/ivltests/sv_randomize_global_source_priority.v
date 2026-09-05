// IEEE 1800-2017 18.5.14.1/.2; 2023 18.5.13.1/.2.
class source_priority;
  rand bit value;
  constraint z_first { soft value == 0; }
  constraint a_second { soft value == 1; }
endclass
class external_priority;
  rand bit value;
  extern constraint z_first;
  extern constraint a_second;
endclass
constraint external_priority::a_second { soft value == 1; }
constraint external_priority::z_first { soft value == 0; }
class implicit_priority;
  rand bit value;
  constraint z_first;
  constraint a_second;
endclass
constraint implicit_priority::a_second { soft value == 1; }
constraint implicit_priority::z_first { soft value == 0; }
module main;
  source_priority s = new;
  external_priority e = new;
  implicit_priority i = new;
  initial begin
    repeat (20) begin
      if (!s.randomize() || s.value != 1) $fatal(1, "alphabetic soft priority");
      if (!e.randomize() || e.value != 1) $fatal(1, "extern body priority");
      if (!i.randomize() || i.value != 1) $fatal(1, "implicit body priority");
    end
    s.a_second.constraint_mode(0);
    e.a_second.constraint_mode(0);
    i.a_second.constraint_mode(0);
    if (!s.randomize() || s.value != 0 || !e.randomize() || e.value != 0
        || !i.randomize() || i.value != 0)
      $fatal(1, "constraint_mode index changed meaning");
    $display("PASSED");
  end
endmodule
