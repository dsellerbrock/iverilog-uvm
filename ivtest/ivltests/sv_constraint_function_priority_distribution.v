function automatic int popcount(bit [3:0] value);
  for (popcount = 0; value != 0; value = value >> 1)
    popcount += value & 1'b1;
endfunction

class C;
  rand bit [3:0] value;
  rand bit [2:0] length;
  rand bit [1:0] peer;
  constraint c {
    length == popcount(value);
    length < 2;
  }
endclass

module test;
  C item;
  int successes;
  int value_count[16];
  int peer_count[4];

  initial begin
    for (int i = 0; i < 16; i++)
      value_count[i] = 0;
    for (int i = 0; i < 4; i++)
      peer_count[i] = 0;
    item = new;
    item.srandom(1);
    for (int i = 0; i < 3200; i++) begin
      if (!item.randomize())
        continue;
      successes++;
      if (!(item.value inside {4'h0, 4'h1, 4'h2, 4'h4, 4'h8}))
        $fatal(1, "unexpected successful value %0h", item.value);
      value_count[item.value]++;
      peer_count[item.peer]++;
    end

    if (successes < 880 || successes > 1120)
      $fatal(1, "unexpected success count %0d", successes);
    if (value_count[0] < 140 || value_count[0] > 260
        || value_count[1] < 140 || value_count[1] > 260
        || value_count[2] < 140 || value_count[2] > 260
        || value_count[4] < 140 || value_count[4] > 260
        || value_count[8] < 140 || value_count[8] > 260)
      $fatal(1, "constrained value counts out of range");
    for (int value = 0; value < 16; value++)
      if (!(value inside {0, 1, 2, 4, 8}) && value_count[value] != 0)
        $fatal(1, "unexpected value count %0d=%0d", value, value_count[value]);
    if (value_count[0] + value_count[1] + value_count[2]
        + value_count[4] + value_count[8] != successes)
      $fatal(1, "legal value counts do not sum to successes");
    for (int peer = 0; peer < 4; peer++)
      if (peer_count[peer] < 185 || peer_count[peer] > 315)
        $fatal(1, "peer count out of range: %0d=%0d", peer, peer_count[peer]);
    $display("PASSED");
  end
endmodule
