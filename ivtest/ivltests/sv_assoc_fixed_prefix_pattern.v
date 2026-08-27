// IEEE 1800-2017/2023 7.4, 7.9.11, and 10.9: a fully selected
// associative-array leaf behind fixed unpacked dimensions is a complete map
// lvalue. Declared ranges determine the fixed-word mapping; an invalid fixed
// selector still evaluates the RHS, but the store is a no-op.
typedef int fixed_assoc_int_map_t[string];

module main;
  bit failed;
  int rhs_evaluations;

  task automatic check(input string label, input logic ok);
    if (ok !== 1'b1) begin
      $display("FAILED -- %0s", label);
      failed = 1'b1;
    end
  endtask

  function automatic fixed_assoc_int_map_t make_map(input int value);
    return '{"value":value, default:-value};
  endfunction

  function automatic fixed_assoc_int_map_t side_effect_map(input int value);
    rhs_evaluations += 1;
    return '{"invalid":value, default:-value};
  endfunction

  function automatic int side_effect_value(input int value);
    rhs_evaluations += 1;
    return value;
  endfunction

  task automatic check_fixed_prefix_maps;
    string direct_entry[2][string];
    bit direct_bits[2][string];
    int method_maps[1:2][string];
    int descending_maps[4:2][string];
    int matrix[-1:1][5:3][string];
    int cube[2:4][-2:0][9:7][string];
    int row;
    int col;
    int expected;
    int direct_index;
    int method_index;
    int invalid_index;
    string method_key;

    // The direct-entry form is a distinct l-value path from whole-map
    // assignment. The sibling fixed slot must remain an independent empty
    // associative array.
    direct_entry[0]["x"] = "y";
    check("direct entry write behind fixed prefix",
          direct_entry[0].size() == 1 &&
          direct_entry[0].exists("x") &&
          direct_entry[0]["x"] == "y");
    check("direct entry sibling independence",
          direct_entry[1].size() == 0 && !direct_entry[1].exists("x"));
    direct_entry[1]["constant"] = "one";
    direct_index = 1;
    direct_entry[direct_index]["variable"] = "two";
    check("constant and variable fixed-prefix direct entries",
          direct_entry[0].size() == 1 &&
          direct_entry[1].size() == 2 &&
          direct_entry[1]["constant"] == "one" &&
          direct_entry[1]["variable"] == "two");

    // Vector-valued leaves use a distinct VVP setter path. Pin lazy creation
    // for both slots, including an explicit zero that must still be a member.
    direct_bits[0]["set"] = 1'b1;
    direct_index = 1;
    direct_bits[direct_index]["clear"] = 1'b0;
    check("vector direct entries behind fixed prefix",
          direct_bits[0].size() == 1 && direct_bits[0].exists("set") &&
          direct_bits[0]["set"] === 1'b1 &&
          direct_bits[1].size() == 1 && direct_bits[1].exists("clear") &&
          direct_bits[1]["clear"] === 1'b0);

    // Methods operate on the selected associative leaf, not a synthetic fixed
    // array signal. Traversal writes the declared key argument in key order;
    // deleting entries must not select or clear the sibling map, and delete()
    // retains the selected map's explicit fallback.
    method_maps[1] = '{"alpha":11, "beta":12, default:-1};
    method_maps[2] = '{"middle":21, "omega":22, default:-2};
    method_index = 1;
    check("selected fixed-map exists",
          method_maps[method_index].exists("alpha") &&
          !method_maps[method_index].exists("missing"));
    method_key = "";
    check("selected fixed-map first",
          method_maps[method_index].first(method_key) &&
          method_key == "alpha");
    check("selected fixed-map next",
          method_maps[method_index].next(method_key) &&
          method_key == "beta");
    check("selected fixed-map last",
          method_maps[method_index].last(method_key) &&
          method_key == "beta");
    check("selected fixed-map prev",
          method_maps[method_index].prev(method_key) &&
          method_key == "alpha");
    method_maps[method_index].delete("alpha");
    check("selected keyed delete preserves sibling and fallback",
          method_maps[1].size() == 1 && !method_maps[1].exists("alpha") &&
          method_maps[1]["absent"] == -1 &&
          method_maps[2].size() == 2 && method_maps[2].exists("middle"));
    method_index = 2;
    method_maps[method_index].delete();
    check("selected delete all preserves sibling and fallback",
          method_maps[2].size() == 0 && !method_maps[2].exists("omega") &&
          method_maps[2]["absent"] == -2 &&
          method_maps[1].size() == 1 && method_maps[1].exists("beta"));

    // A nonzero descending range must map each declared index to a distinct
    // map. Explicit entries contribute to size; default is fallback state and
    // does not insert an absent key.
    descending_maps[4] = '{"value":40, default:-40};
    descending_maps[3] = '{"value":30, default:-30};
    descending_maps[2] = '{"value":20, default:-20};
    descending_maps[3]["direct"] = 303;
    check("descending high slot",
          descending_maps[4].size() == 1 &&
          descending_maps[4]["value"] == 40 &&
          !descending_maps[4].exists("absent") &&
          descending_maps[4]["absent"] == -40 &&
          descending_maps[4].size() == 1);
    check("descending middle slot and direct entry",
          descending_maps[3].size() == 2 &&
          descending_maps[3]["value"] == 30 &&
          descending_maps[3]["direct"] == 303 &&
          descending_maps[3]["absent"] == -30 &&
          !descending_maps[3].exists("absent"));
    check("descending low slot",
          descending_maps[2].size() == 1 &&
          descending_maps[2]["value"] == 20 &&
          descending_maps[2]["absent"] == -20 &&
          !descending_maps[2].exists("absent"));

    // Two mixed-direction, nonzero fixed dimensions. Constant stores followed
    // by variable reads prove the two canonicalization paths agree for every
    // corner, edge, and interior slot.
    matrix[-1][5] = make_map(105);
    matrix[-1][4] = make_map(104);
    matrix[-1][3] = make_map(103);
    matrix[0][5] = make_map(205);
    matrix[0][4] = make_map(204);
    matrix[0][3] = make_map(203);
    matrix[1][5] = make_map(305);
    matrix[1][4] = make_map(304);
    matrix[1][3] = make_map(303);
    for (row = -1; row <= 1; row += 1) begin
      for (col = 5; col >= 3; col -= 1) begin
        expected = (row + 2) * 100 + col;
        check($sformatf("2D fixed map [%0d][%0d]", row, col),
              matrix[row][col].size() == 1 &&
              matrix[row][col].exists("value") &&
              matrix[row][col]["value"] == expected &&
              !matrix[row][col].exists("absent") &&
              matrix[row][col]["absent"] == -expected &&
              matrix[row][col].size() == 1);
      end
    end

    // A flat bounds check is insufficient for multidimensional prefixes:
    // [-1][6] would flatten to the valid word for [0][3], [0][6] to [1][3],
    // and [1][2] to [0][5]. Every variable fixed dimension must therefore be
    // checked before flattening. Pin the whole-map l-value, direct-entry
    // l-value, entry r-value, and task-method receiver paths independently.
    rhs_evaluations = 0;
    row = -1;
    col = 6;
    matrix[row][col] = side_effect_map(910);
    check("2D OOB whole-map RHS evaluates once", rhs_evaluations == 1);
    check("2D OOB whole-map store cannot alias sibling",
          matrix[0][3].size() == 1 &&
          matrix[0][3]["value"] == 203 &&
          matrix[0][3]["absent"] == -203);

    row = 0;
    col = 6;
    matrix[row][col]["alias"] = side_effect_value(911);
    check("2D OOB direct-entry RHS evaluates once", rhs_evaluations == 2);
    check("2D OOB direct-entry store cannot alias sibling",
          matrix[1][3].size() == 1 &&
          !matrix[1][3].exists("alias") &&
          matrix[1][3]["value"] == 303);

    row = 1;
    col = 2;
    expected = matrix[row][col]["value"];
    check("2D OOB entry read cannot alias sibling", expected !== 205);

    row = -1;
    col = 6;
    matrix[row][col].delete("value");
    check("2D OOB map method cannot alias sibling",
          matrix[0][3].size() == 1 &&
          matrix[0][3].exists("value") &&
          matrix[0][3]["value"] == 203);

    // Three mixed-direction, nonzero dimensions pin all eight corners plus a
    // true interior slot. This distinguishes the complete fixed outer-array
    // word count from the associative leaf's queue-compatible metadata.
    cube[2][-2][9] = make_map(2109);
    cube[2][-2][7] = make_map(2107);
    cube[2][0][9] = make_map(2309);
    cube[2][0][7] = make_map(2307);
    cube[4][-2][9] = make_map(4109);
    cube[4][-2][7] = make_map(4107);
    cube[4][0][9] = make_map(4309);
    cube[4][0][7] = make_map(4307);
    cube[3][-1][8] = make_map(3208);
    check("3D corner 2,-2,9",
          cube[2][-2][9].size() == 1 &&
          cube[2][-2][9]["value"] == 2109 &&
          cube[2][-2][9]["absent"] == -2109);
    check("3D corner 2,-2,7",
          cube[2][-2][7].size() == 1 &&
          cube[2][-2][7]["value"] == 2107 &&
          cube[2][-2][7]["absent"] == -2107);
    check("3D corner 2,0,9",
          cube[2][0][9].size() == 1 &&
          cube[2][0][9]["value"] == 2309 &&
          cube[2][0][9]["absent"] == -2309);
    check("3D corner 2,0,7",
          cube[2][0][7].size() == 1 &&
          cube[2][0][7]["value"] == 2307 &&
          cube[2][0][7]["absent"] == -2307);
    check("3D corner 4,-2,9",
          cube[4][-2][9].size() == 1 &&
          cube[4][-2][9]["value"] == 4109 &&
          cube[4][-2][9]["absent"] == -4109);
    check("3D corner 4,-2,7",
          cube[4][-2][7].size() == 1 &&
          cube[4][-2][7]["value"] == 4107 &&
          cube[4][-2][7]["absent"] == -4107);
    check("3D corner 4,0,9",
          cube[4][0][9].size() == 1 &&
          cube[4][0][9]["value"] == 4309 &&
          cube[4][0][9]["absent"] == -4309);
    check("3D corner 4,0,7",
          cube[4][0][7].size() == 1 &&
          cube[4][0][7]["value"] == 4307 &&
          cube[4][0][7]["absent"] == -4307);
    check("3D interior 3,-1,8",
          cube[3][-1][8].size() == 1 &&
          cube[3][-1][8]["value"] == 3208 &&
          cube[3][-1][8]["absent"] == -3208);

    // Invalid fixed selectors make the whole-map store a no-op, but normal
    // expression evaluation still evaluates each RHS exactly once. Cover one
    // constant OOB index and variable negative, too-large, and X indices.
    rhs_evaluations = 0;
    descending_maps[1] = side_effect_map(901);
    invalid_index = -7;
    descending_maps[invalid_index] = side_effect_map(902);
    invalid_index = 99;
    descending_maps[invalid_index] = side_effect_map(903);
    invalid_index = 'x;
    descending_maps[invalid_index] = side_effect_map(904);
    check("invalid fixed selectors evaluate every RHS",
          rhs_evaluations == 4);
    check("invalid fixed selectors preserve high slot",
          descending_maps[4].size() == 1 &&
          descending_maps[4]["value"] == 40 &&
          descending_maps[4]["absent"] == -40);
    check("invalid fixed selectors preserve middle slot",
          descending_maps[3].size() == 2 &&
          descending_maps[3]["value"] == 30 &&
          descending_maps[3]["direct"] == 303 &&
          descending_maps[3]["absent"] == -30);
    check("invalid fixed selectors preserve low slot",
          descending_maps[2].size() == 1 &&
          descending_maps[2]["value"] == 20 &&
          descending_maps[2]["absent"] == -20);
  endtask

  initial begin
    failed = 1'b0;
    rhs_evaluations = 0;
    check_fixed_prefix_maps();
    if (failed)
      $display("FAILED");
    else
      $display("PASSED");
  end
endmodule
