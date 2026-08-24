// Whole fixed-array class-property assignment copies every queue-valued slot
// by value (IEEE 1800-2017 7.6 and 10.8).

class fixed_container_outer_assignment_holder;
  int values[2][$];
  int maps[2][string];
endclass

module sv_class_fixed_array_container_outer_assignment;
  initial begin
    automatic fixed_container_outer_assignment_holder lhs = new;
    automatic fixed_container_outer_assignment_holder rhs = new;

    lhs.values[0].push_back(99);
    rhs.values[0].push_back(11);
    rhs.values[1].push_back(22);
    lhs.maps[0]["old"] = 99;
    rhs.maps[0]["a"] = 31;
    rhs.maps[1]["b"] = 41;
    lhs.values = rhs.values;
    lhs.maps = rhs.maps;

    rhs.values[0][0] = 33;
    rhs.values[1].push_back(44);
    rhs.maps[0]["a"] = 51;
    rhs.maps[1]["c"] = 61;
    if (lhs.values[0].size() != 1 || lhs.values[0][0] != 11 ||
        lhs.values[1].size() != 1 || lhs.values[1][0] != 22 ||
        rhs.values[0][0] != 33 || rhs.values[1].size() != 2 ||
        lhs.maps[0].num() != 1 || lhs.maps[0]["a"] != 31 ||
        lhs.maps[1].num() != 1 || lhs.maps[1]["b"] != 41 ||
        rhs.maps[0]["a"] != 51 || rhs.maps[1].num() != 2)
      $fatal(1, "whole fixed-array queue-property assignment did not value-copy");

    $display("PASSED");
  end
endmodule
