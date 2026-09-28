// IEEE 1800-2017/2023 12.7.3: skipping an associative key still iterates
// the declared fixed child bounds, even if the associative map is empty.
typedef enum int { Data, Info } part_t;

class memory;
  int value;
  function new(int v); value = v; endfunction
endclass

class cfg;
  memory map[part_t][3:1];
endclass

module top;
  cfg c, empty;
  memory signal_map[part_t][2:3];
  int scalar_map[part_t];
  part_t part;
  int visits, empty_visits, signal_visits;

  initial begin
    c = new;
    empty = new;
    for (int b = 1; b <= 3; b++) begin
      c.map[Data][b] = new(10+b);
      c.map[Info][b] = new(20+b);
    end
    part = Data;
    repeat (2) begin
      foreach (c.map[,bank]) begin
        if (bank != 3 - visits % 3 ||
            c.map[part][bank].value != (part == Data ? 10 : 20) + bank)
          $fatal(1, "wrong class bank part=%0d bank=%0d", part, bank);
        visits++;
      end
      part = part.next();
    end
    if (visits != 6) $fatal(1, "class visits=%0d", visits);

    foreach (empty.map[,bank]) begin
      if (bank != 3 - empty_visits)
        $fatal(1, "empty class bank=%0d", bank);
      empty_visits++;
    end
    if (empty_visits != 3 || empty.map.exists(Data))
      $fatal(1, "empty class map changed");

    foreach (signal_map[,bank]) begin
      if (bank != 2 + signal_visits)
        $fatal(1, "signal bank=%0d", bank);
      signal_visits++;
    end
    if (signal_visits != 2 || signal_map.exists(Data))
      $fatal(1, "empty signal map changed");

    foreach (c.map[,]) $fatal(1, "all-omitted body executed");
    foreach (scalar_map[]) $fatal(1, "single-omitted body executed");
    $display("PASSED");
  end
endmodule
