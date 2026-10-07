module sv_array_map_assoc_2023;
  typedef int map_row_t[1:0];
  int source[string];
  int mapped[string];
  string labels[string];
  int empty_source[string];
  int empty_mapped[string];
  map_row_t source_rows[string];
  map_row_t copied_rows[string];

  initial begin
    source["a"] = 10;
    source["bb"] = 20;
    mapped = source.map(value, key) with
        (int'(value + (value.key == "a")));
    if (mapped.num() != 2 || !mapped.exists("a")
        || !mapped.exists("bb") || mapped["a"] != 11
        || mapped["bb"] != 20)
      $fatal(1, "associative map keys/values");

    labels = source.map(value, key) with
        ($sformatf("%s:%0d", value.key, value));
    if (labels.num() != 2 || labels["a"] != "a:10"
        || labels["bb"] != "bb:20")
      $fatal(1, "associative map string values");

    empty_mapped = empty_source.map(value, key) with (value);
    if (empty_mapped.num() != 0)
      $fatal(1, "empty associative map result");

    source_rows["a"][1] = 1;
    source_rows["a"][0] = 2;
    source_rows["bb"][1] = 3;
    source_rows["bb"][0] = 4;
    copied_rows = source_rows.map(row, key) with (row);
    if (copied_rows.num() != 2 || !copied_rows.exists("a")
        || !copied_rows.exists("bb") || copied_rows["a"][1] != 1
        || copied_rows["a"][0] != 2 || copied_rows["bb"][1] != 3
        || copied_rows["bb"][0] != 4)
      $fatal(1, "associative array-valued map result");
    $display("PASSED");
  end
endmodule
