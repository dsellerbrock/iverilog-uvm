// foreach (h.mem[i][j]) where `i' is declared outside leaves the remaining
// fixed dimension of a class property to iterate (IEEE 1800-2017/2023
// 12.7.3). The property is a fixed array of fixed arrays of containers
// (OpenTitan flash_ctrl otf_scb_h.info_mem[bank][type][addr]); only the
// selected bank's rows may be touched.
class scb;
  bit [7:0] info_mem[2][3][bit[3:0]];
  bit [7:0] qm[2][3][$];
  int visited[$];
endclass

module main;
  int errors;
  scb h = new;

  task automatic clear_bank(int bank);
    foreach (h.info_mem[bank][t]) begin
      h.info_mem[bank][t].delete();
      h.visited.push_back(t);
    end
    foreach (h.qm[bank][t]) h.qm[bank][t].delete();
  endtask

  task automatic check(string what, int got, int want);
    if (got !== want) begin
      $display("FAILED %s: got %0d want %0d", what, got, want);
      errors++;
    end
  endtask

  initial begin
    for (int b = 0; b < 2; b++)
      for (int t = 0; t < 3; t++) begin
        h.info_mem[b][t][4'(t)] = 8'(b * 16 + t);
        h.qm[b][t].push_back(b);
      end
    clear_bank(1);
    check("visited count", h.visited.size(), 3);
    check("visited[0]", h.visited[0], 0);
    check("visited[2]", h.visited[2], 2);
    for (int t = 0; t < 3; t++) begin
      check("bank0 map kept", h.info_mem[0][t].num(), 1);
      check("bank1 map cleared", h.info_mem[1][t].num(), 0);
      check("bank0 queue kept", h.qm[0][t].size(), 1);
      check("bank1 queue cleared", h.qm[1][t].size(), 0);
    end
    if (errors == 0) $display("PASSED");
  end
endmodule
