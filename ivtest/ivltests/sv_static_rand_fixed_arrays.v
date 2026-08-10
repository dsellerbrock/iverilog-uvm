// Static fixed arrays use one declaring .array object. Constraint/runtime
// indices and direct/member indices must select the same numeric word for
// both range directions; every element is unique to expose reversal/aliasing.
typedef struct {
  int x;
  int y;
} static_point_t;

class static_array_holder;
  static rand int ascending[3:6];
  static rand int descending[6:3];
  static static_point_t pool[3:6];

  constraint fixed_words {
    ascending[3] == 103;
    ascending[4] == 104;
    ascending[5] == 105;
    ascending[6] == 106;
    descending[3] == 203;
    descending[4] == 204;
    descending[5] == 205;
    descending[6] == 206;
  }
endclass

module test;
  initial begin
    static_array_holder first;
    static_array_holder second;
    int idx;

    first = new;
    second = new;
    if (first.randomize() !== 1)
      $fatal(1, "fixed-array randomize failed");

    for (idx = 3; idx <= 6; idx++) begin
      if (static_array_holder::ascending[idx] !== 100 + idx
          || first.ascending[idx] !== 100 + idx
          || second.ascending[idx] !== 100 + idx)
        $fatal(1, "ascending word mismatch at %0d", idx);
      if (static_array_holder::descending[idx] !== 200 + idx
          || first.descending[idx] !== 200 + idx
          || second.descending[idx] !== 200 + idx)
        $fatal(1, "descending word mismatch at %0d", idx);
    end

    second.ascending[4] = 314;
    static_array_holder::descending[5] = 415;
    if (static_array_holder::ascending[4] !== 314
        || first.ascending[4] !== 314
        || first.descending[5] !== 415
        || second.descending[5] !== 415)
      $fatal(1, "fixed-array member/direct writes were not shared");

    // The first assignment is the formerly rejected h.pool[i].x form:
    // a fixed-array static followed by a packed/struct member path.
    idx = 4;
    first.pool[idx].x = 504;
    second.pool[5].y = 605;
    static_array_holder::pool[3].x = 503;
    if (static_array_holder::pool[4].x !== 504
        || second.pool[4].x !== 504
        || first.pool[5].y !== 605
        || second.pool[3].x !== 503)
      $fatal(1, "array-of-struct indexed member write was not shared");

    $display("PASSED");
  end
endmodule
