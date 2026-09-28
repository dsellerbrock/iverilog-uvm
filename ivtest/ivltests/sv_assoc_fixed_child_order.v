// An enum-keyed associative entry is a live fixed array for ordering.
typedef enum int { Data, Info, Spare, Other } part_t;
typedef bit [3:0] row_t [0:7];

class cfg_t;
  row_t map[part_t];
  part_t selected;
  int calls;
  function part_t pick(); calls++; return selected; endfunction
endclass

module top;
  cfg_t cfg;
  bit [7:0] seen;
  bit changed;
  int value;
  initial begin
    cfg = new;
    cfg.map = '{default: row_t'{1,2,3,4,5,6,7,8}};
    for (int i = 0; i < 8; i++) begin
      cfg.map[Data][i] = i;
      cfg.map[Info][i] = i + 8;
    end

    cfg.selected = Data;
    cfg.map[cfg.pick()].reverse();
    if (cfg.calls != 1) $fatal(1, "key evaluated more than once");
    for (int i = 0; i < 8; i++)
      if (cfg.map[Data][i] != 7-i || cfg.map[Info][i] != i+8)
        $fatal(1, "existing-key reverse or sibling isolation");

    if (cfg.map.exists(Spare) || cfg.map.exists(Other))
      $fatal(1, "default read inserted a key");
    cfg.selected = Spare;
    cfg.map[cfg.pick()].reverse();
    if (cfg.calls != 2 || !cfg.map.exists(Spare)
        || cfg.map.exists(Other))
      $fatal(1, "missing-key reverse did not store a private child");
    for (int i = 0; i < 8; i++)
      if (cfg.map[Spare][i] != 8-i || cfg.map[Other][i] != i+1)
        $fatal(1, "missing-key default was not copied");

    cfg.selected = Info;
    repeat (12) begin
      cfg.map[cfg.pick()].shuffle();
      seen = '0;
      for (int i = 0; i < 8; i++) begin
        value = cfg.map[Info][i];
        if (value < 8 || value > 15 || seen[value-8])
          $fatal(1, "shuffle lost or duplicated an element");
        seen[value-8] = 1;
        if (value != i+8) changed = 1;
      end
      if (seen != '1) $fatal(1, "shuffle missing element");
    end
    if (!changed || cfg.calls != 14)
      $fatal(1, "shuffle did not reorder or key evaluated twice");
    for (int i = 0; i < 8; i++)
      if (cfg.map[Data][i] != 7-i || cfg.map[Spare][i] != 8-i
          || cfg.map[Other][i] != i+1 || cfg.map.exists(Other))
        $fatal(1, "shuffle changed another key or shared default");
    $display("PASSED");
  end
endmodule
