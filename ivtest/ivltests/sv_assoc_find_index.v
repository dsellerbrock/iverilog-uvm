// IEEE 1800-2017/2023 7.12.1: associative find_index returns matching keys.
class sv_assoc_find_index_box;
  int values[bit [7:0]];
endclass

module sv_assoc_find_index;
  sv_assoc_find_index_box box;
  int values[bit [7:0]];
  bit [7:0] hits[$];
  int empty_values[int];
  int empty_hits[$];
  int signed_values[int];
  int signed_hits[$];
  int words[string];
  string names[$];

  initial begin
    box = new;
    values[8'h20] = 3;
    values[8'h03] = -1;
    values[8'h10] = 2;
    values[8'hf0] = 4;
    hits = values.find_index() with (item > 0);
    if (hits.size() != 3 || hits[0] !== 8'h10 || hits[1] !== 8'h20
        || hits[2] !== 8'hf0)
      $fatal(1, "find_index must return matching keys in key order");
    empty_hits = empty_values.find_index() with (item > 0);
    if (empty_hits.size() != 0)
      $fatal(1, "empty associative find_index result");
    hits = values.find_index(k) with (k > 100);
    if (hits.size() != 0)
      $fatal(1, "no-match associative find_index result");
    hits = values.find_index(k) with (k.index == 8'h20);
    if (hits.size() != 1 || hits[0] !== 8'h20)
      $fatal(1, "iterator.index did not preserve the associative key");
    if (values.num() != 4 || values[8'h03] != -1)
      $fatal(1, "find_index changed its receiver");

    signed_values[5] = 1;
    signed_values[-2] = 1;
    signed_hits = signed_values.find_index() with (item > 0);
    if (signed_hits.size() != 2 || signed_hits[0] != -2 || signed_hits[1] != 5)
      $fatal(1, "signed associative keys lost their order or sign");

    box.values[8'h42] = 7;
    box.values[8'h11] = 1;
    hits = box.values.find_index() with (item == 7);
    if (hits.size() != 1 || hits[0] !== 8'h42)
      $fatal(1, "class property associative receiver");

    words["zebra"] = 1;
    words["alpha"] = 2;
    names = words.find_index() with (item > 0);
    if (names.size() != 2 || names[0] != "alpha" || names[1] != "zebra")
      $fatal(1, "string associative find_index keys");
    $display("ASSOC_FIND_INDEX_PASS");
  end
endmodule
