// foreach with more than one fixed selector before the looped dimension,
// and selectors that are parameters or imported enum constants (IEEE
// 1800-2017/2023 12.7.3). OpenTitan flash_ctrl DV uses all three:
//   foreach (part_address_ranges_written[bank][part][i]) ...
//   foreach (tgt_pre[FlashPartData][i]) ...
//   constraint { foreach (rand_info[i, j]) foreach (rand_info[i][j][k]) ... }
package fp;
  typedef enum { PartData, PartInfo } part_e;
  localparam int Fixed = 1;
endpackage

module test;
  import fp::*;
  typedef struct { int first; int last; } r_t;

  class c;
    rand bit [3:0] v[2][3][4];
    constraint ci {
      foreach (v[i, j]) {
        foreach (v[i][j][k]) {
          v[i][j][k] == i * 4 + j + k;
        }
      }
    }
  endclass

  r_t ranges[2][part_e][$];
  int grid[2][3];
  int by_part[2][4];
  bit ok = 1;

  initial begin
    automatic c o = new;
    automatic int n = 0, s = 0, bad = 0;

    ranges[1][PartInfo].push_back('{1, 2});
    ranges[1][PartInfo].push_back('{3, 4});
    for (int bank = 0; bank < 2; ++bank)
      foreach (ranges[bank][part])
        foreach (ranges[bank][part][i]) begin
          automatic r_t range = ranges[bank][part][i];
          n += range.first + range.last;
        end
    if (n != 10) begin $display("FAILED: n=%0d", n); ok = 0; end

    foreach (grid[Fixed][j]) grid[Fixed][j] = j + 1;
    foreach (by_part[PartInfo][i]) by_part[PartInfo][i] = 10 * i;
    foreach (grid[a, b]) s += grid[a][b];
    foreach (by_part[a, b]) s += by_part[a][b];
    if (s != 6 + 60) begin $display("FAILED: s=%0d", s); ok = 0; end

    if (!o.randomize()) begin $display("FAILED: randomize"); ok = 0; end
    foreach (o.v[i, j, k]) if (o.v[i][j][k] != i * 4 + j + k) bad++;
    if (bad) begin $display("FAILED: bad=%0d", bad); ok = 0; end

    if (ok) $display("PASSED");
  end
endmodule
