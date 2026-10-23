class C;
  rand byte x;
  rand int y;
  constraint c { unique {x, y}; }
endclass

module sv_unique_constraint_non_equivalent_2017;
  initial begin
    C o;
    o = new;
    $display("%0d", o.randomize());
  end
endmodule
