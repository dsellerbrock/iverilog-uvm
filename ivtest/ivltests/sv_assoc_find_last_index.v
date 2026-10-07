module sv_assoc_find_last_index;
  int values[int];
  int hits[$];
  int signed_values[int];
  int signed_hits[$];
  int empty_values[int];
  int empty_hits[$];
  int words[string];
  string names[$];

  initial begin
    values[3] = 10;
    values[12] = 40;
    values[7] = 30;
    values[10] = 5;
    values[15] = 5;
    hits = values.find_last_index() with (item > 20);
    if (hits.size() != 1 || hits[0] !== 12)
      $fatal(1, "find_last_index must return the last matching associative key");

    hits = values.find_last_index() with (item > 100);
    if (hits.size() != 0)
      $fatal(1, "find_last_index must return an empty queue when no item matches");
    empty_hits = empty_values.find_last_index() with (item > 0);
    if (empty_hits.size() != 0)
      $fatal(1, "find_last_index on an empty associative array");

    signed_values[5] = 9;
    signed_values[-2] = 3;
    signed_values[0] = 5;
    signed_hits = signed_values.find_last_index() with (item >= 3);
    if (signed_hits.size() != 1 || signed_hits[0] !== 5)
      $fatal(1, "find_last_index must use signed associative key ordering");

    words["zebra"] = 1;
    words["alpha"] = 2;
    names = words.find_last_index() with (item > 0);
    if (names.size() != 1 || names[0] != "zebra")
      $fatal(1, "find_last_index must preserve string associative keys");

    $display("ASSOC_FIND_LAST_INDEX_PASS");
  end
endmodule
