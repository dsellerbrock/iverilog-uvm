// IEEE 1800-2017/2023 7.12.1: array locator methods also operate on
// multidimensional unpacked arrays, with each iterator value one subarray.
module sv_array_locator_multidim;
  int values[5:4][9:8];
  int rows[$][9:8];
  int indexes[$];

  initial begin
    values[5][9] = 10;
    values[5][8] = 20;
    values[4][9] = 30;
    values[4][8] = 40;

    rows = values.find_first(row) with (row[8] >= 20);
    if (rows.size() != 1 || rows[0][9] != 10 || rows[0][8] != 20)
      $fatal(1, "multidimensional find_first failed");
    indexes = values.find_first_index(row) with (row[8] >= 20);
    if (indexes.size() != 1 || indexes[0] != 5)
      $fatal(1, "multidimensional find_first_index failed");

    rows = values.find_last(row) with (row[8] >= 20);
    if (rows.size() != 1 || rows[0][9] != 30 || rows[0][8] != 40)
      $fatal(1, "multidimensional find_last failed");
    indexes = values.find_last_index(row) with (row[8] >= 20);
    if (indexes.size() != 1 || indexes[0] != 4)
      $fatal(1, "multidimensional find_last_index failed");

    indexes = values.find_index(row) with (row[8] >= 20);
    if (indexes.size() != 2
        || !((indexes[0] == 5 && indexes[1] == 4)
             || (indexes[0] == 4 && indexes[1] == 5)))
      $fatal(1, "multidimensional find_index failed");
    rows = values.find(row) with (row.index >= 0 && row[9] > 99);
    if (rows.size() != 0)
      $fatal(1, "multidimensional no-match result was not empty");

    $display("PASSED");
  end
endmodule
