module test;
  logic [7:0] logic_tab[4];
  bit [7:0] bit_tab[4];
  int i;
  int ok;

  initial begin
    logic_tab = '{8'h11, 8'h22, 8'h33, 8'h44};
    bit_tab = '{8'h11, 8'h22, 8'h33, 8'h44};

    i = 0;
    ok = std::randomize(i) with { i inside {[0:3]}; logic_tab[i] == 8'h44; };
    if (ok !== 1 || i != 3) $fatal(1, "logic array select: %0d %0d", ok, i);

    i = 0;
    ok = std::randomize(i) with { i inside {[0:3]}; bit_tab[i] == 8'h44; };
    if (ok !== 1 || i != 3) $fatal(1, "bit array select: %0d %0d", ok, i);

    i = 2;
    ok = std::randomize(i) with { i inside {[0:3]}; logic_tab[i] == 8'h99; };
    if (ok !== 0 || i != 2) $fatal(1, "unsatisfiable array select: %0d %0d", ok, i);

    $display("PASS");
  end
endmodule
