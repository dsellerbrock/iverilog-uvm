module test;
  int numeric[int];
  int names[string];
  int defaults[int];
  int any_index_map[*];

  initial begin
    int key;
    string name;

    numeric[-2] = 20;
    numeric[0] = 10;
    numeric[7] = 70;
    if (numeric.num() != 3 || numeric.size() != 3
        || !numeric.exists(-2) || numeric.exists(1))
      $fatal(1, "associative count/exists mismatch");
    if (!numeric.first(key) || key != -2
        || !numeric.next(key) || key != 0
        || !numeric.next(key) || key != 7
        || numeric.next(key) || key != 7)
      $fatal(1, "signed associative next traversal mismatch");
    if (!numeric.last(key) || key != 7
        || !numeric.prev(key) || key != 0
        || !numeric.prev(key) || key != -2
        || numeric.prev(key) || key != -2)
      $fatal(1, "signed associative prev traversal mismatch");
    numeric.delete(0);
    if (numeric.num() != 2 || numeric.exists(0))
      $fatal(1, "indexed associative delete mismatch");
    numeric.delete();
    if (numeric.num() != 0 || numeric.first(key))
      $fatal(1, "whole associative delete mismatch");

    names = '{"pear": 3, "apple": 1, "": 0, default: -1};
    if (names.num() != 3 || names["apple"] != 1
        || names["missing"] != -1 || names.exists("missing"))
      $fatal(1, "associative literal/default mismatch");
    if (!names.first(name) || name != ""
        || !names.next(name) || name != "apple"
        || !names.next(name) || name != "pear"
        || names.next(name) || name != "pear")
      $fatal(1, "string associative traversal mismatch");
    names.delete("apple");
    if (names.exists("apple") || names.num() != 2)
      $fatal(1, "string associative indexed delete mismatch");

    any_index_map[32'd8] = 8;
    any_index_map[8'b00001000] = 80;
    if (any_index_map.num() != 1 || !any_index_map.exists(4'b1000)
        || any_index_map[4'b1000] != 80)
      $fatal(1, "wildcard integral key normalization mismatch");

    defaults = '{default: -5};
    if (defaults.num() != 0 || defaults.exists(9) || defaults[9] != -5)
      $fatal(1, "default associative literal affected membership or value");

    $display("PASS §7.8/§7.9 associative arrays, methods, literals");
    $finish;
  end
endmodule
