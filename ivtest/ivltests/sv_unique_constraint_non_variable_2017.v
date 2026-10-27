class C;
  rand byte x, y;
  constraint c { unique {x + 1, y}; }
endclass

module sv_unique_constraint_non_variable_2017;
  initial begin
    C o;
    o = new;
    $display("%0d", o.randomize());
  end
endmodule
