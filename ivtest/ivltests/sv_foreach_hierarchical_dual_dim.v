// IEEE 1800-2017/2023 12.7.3: only the final list declares loop variables.
// Historical basename retained; traversal of both levels needs two loops.
typedef struct { int v[3]; } holder_t;
module main;
  holder_t h[2];
  int matrix[2][3];
  localparam int ROW = 1;
  int selected, count, sum;
  initial begin
    h[0].v = '{5, 9, 20}; h[1].v = '{1, 2, 3};
    selected = 1;
    count = 0; sum = 0;
    foreach (h[selected].v[i]) begin count++; sum += h[selected].v[i]; end
    if (count != 3 || sum != 6 || selected != 1)
      $fatal(1, "selected prefix was iterated or changed");
    count = 0; sum = 0;
    foreach (h[ROW].v[i]) begin count++; sum += h[ROW].v[i]; end
    if (count != 3 || sum != 6) $fatal(1, "constant prefix changed");
    count = 0; sum = 0;
    foreach (h[selected+0].v[i]) begin count++; sum += h[selected].v[i]; end
    if (count != 3 || sum != 6) $fatal(1, "expression prefix changed");
    count = 0; sum = 0;
    foreach (h[k]) foreach (h[k].v[i]) begin count++; sum += h[k].v[i]; end
    if (count != 6 || sum != 40) $fatal(1, "explicit nested traversal failed");
    count = 0;
    foreach (matrix[i,j]) begin matrix[i][j] = i*3+j; count++; end
    if (count != 6 || matrix[1][2] != 5) $fatal(1, "ordinary multidimensional loop changed");
    $display("PASSED");
  end
endmodule
