// IEEE 1800-2017 10.10: runtime-sized unpacked-array concatenation.
module darray_concat_struct_test;
  typedef struct {
    int id;
    bit [7:0] tag;
  } item_t;

  item_t prefix[];
  item_t result[];
  item_t a;
  item_t b;
  item_t c;

  initial begin
    a = '{11, 8'hA1};
    b = '{22, 8'hB2};
    c = '{33, 8'hC3};
    prefix = new[2];
    prefix[0] = a;
    prefix[1] = b;

    result = {prefix, c};
    if (result.size() != 3 || result[0].id != 11
        || result[1].id != 22 || result[2].id != 33
        || result[0].tag != 8'hA1 || result[2].tag != 8'hC3) begin
      $display("FAIL: darray concat order/size");
      $fatal(1);
    end

    // Struct elements are values: neither a later source-element write nor
    // a later scalar write may alias the concatenation result.
    prefix[0].id = 99;
    c.id = 77;
    if (result[0].id != 11 || result[2].id != 33) begin
      $display("FAIL: darray concat aliased source elements");
      $fatal(1);
    end

    result = {a, prefix, c};
    if (result.size() != 4 || result[0].id != 11
        || result[1].id != 99 || result[2].id != 22
        || result[3].id != 77) begin
      $display("FAIL: mixed darray concat");
      $fatal(1);
    end

    $display("PASS: runtime-sized darray struct concatenation");
  end
endmodule
