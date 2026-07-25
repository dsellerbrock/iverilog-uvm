// M10-1/R7: assigning a whole unpacked array of class handles to a single
// handle is not assignment-compatible (IEEE 1800-2017 7.4 / 8.3) and must be
// rejected.
//
// tgt-vvp used to load element 0 and carry on, so this compiled and behaved
// as if the author had written `h = arr[0]' -- silent acceptance of illegal
// input, which is exactly what this suite exists to catch.
module object_array_to_handle;
  class C;
    int id;
  endclass

  C arr[4];
  C h;

  initial begin
    for (int i = 0; i < 4; i++) begin
      arr[i] = new;
      arr[i].id = i;
    end
    h = arr;            // illegal: whole array to a single handle
    $display("%0d", h.id);
  end
endmodule
