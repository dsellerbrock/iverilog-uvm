// IEEE 1800-2017/2023 7.12.1: a fixed unpacked-array class property
// supports locator iteration over its outer dimension.
class fixed_property_locator;
  int matrix[1:0][1:0];
endclass

module sv_array_locator_fixed_property_multidim;
  fixed_property_locator h;
  int found[$][1:0];

  initial begin
    h = new;
    h.matrix[0][0] = 10;
    h.matrix[0][1] = 20;
    h.matrix[1][0] = 30;
    h.matrix[1][1] = 40;

    found = h.matrix.find(row) with (row[0] > 0);
    if (found.size() != 2 || found[0][0] != 30 || found[1][0] != 10)
      $fatal(1, "multidimensional fixed-property locator failed");

    $display("PASSED");
  end
endmodule
