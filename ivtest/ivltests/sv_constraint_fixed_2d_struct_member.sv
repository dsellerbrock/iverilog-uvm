typedef struct packed {
  bit signed [7:0] low;
  bit [7:0] high;
  bit enabled;
} cell_t;

class grid_t;
  rand cell_t cells[3:2][1:0];
  bit contradict;
  constraint c {
    foreach (cells[i,j]) {
      cells[i][j].low == -((i - 2) * 10 + j + 1);
      cells[i][j].high == (i - 2) * 10 + j + 2;
      cells[i][j].enabled == (j == 1);
    }
    if (contradict) cells[2][0].low == 0;
  }
endclass

module test;
  grid_t item = new;
  cell_t saved[3:2][1:0];
  initial begin
    if (!item.randomize()) $fatal(1, "grid randomization failed");
    foreach (item.cells[i,j]) begin
      if (item.cells[i][j].low != -((i - 2) * 10 + j + 1)
          || item.cells[i][j].high != (i - 2) * 10 + j + 2
          || item.cells[i][j].enabled != (j == 1))
        $fatal(1, "wrong cell at %0d,%0d", i, j);
      saved[i][j] = item.cells[i][j];
    end
    item.contradict = 1;
    if (item.randomize()) $fatal(1, "contradiction was accepted");
    foreach (item.cells[i,j])
      if (item.cells[i][j] !== saved[i][j])
        $fatal(1, "failed randomize changed cell at %0d,%0d", i, j);
    $display("PASSED");
  end
endmodule
