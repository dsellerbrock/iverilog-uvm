module main;
  int ascending[1:5];
  int descending[9:5];
  int result[];
  logic [7:0] four_state[1:3];
  logic [7:0] four_result[];
  initial begin
    foreach (ascending[i]) ascending[i] = i * 10;
    foreach (descending[i]) descending[i] = i * 10;
    result = new[5];
    result = ascending[2:4];
    if (result.size() != 3 || result[0] !== 20 ||
        result[1] !== 30 || result[2] !== 40) $fatal(1, "ascending");
    ascending[2] = 99;
    if (result[0] !== 20) $fatal(1, "copy independence");
    result = descending[8:7];
    if (result.size() != 2 || result[0] !== 80 || result[1] !== 70)
      $fatal(1, "descending");
    result = descending[7 +: 2];
    if (result.size() != 2 || result[0] !== 80 || result[1] !== 70)
      $fatal(1, "indexed slice");
    four_state[2] = 8'hx5;
    four_result = four_state[2:2];
    if (four_result.size() != 1 || four_result[0] !== 8'hx5)
      $fatal(1, "four-state");
    $display("PASS");
  end
endmodule
