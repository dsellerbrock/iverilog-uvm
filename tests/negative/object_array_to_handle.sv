// M10-1/R7: assigning a whole unpacked array of class handles to a single
// handle is not assignment-compatible (IEEE 1800-2017 7.4 / 8.3) and must be
// rejected.
//
// Rejected at ELABORATION (M10-1c), which is the only layer that can see
// the target type. tgt-vvp sees the same whole-array expression for this and
// for the LEGAL `C q[]; q = arr;', so a codegen-level check had to either
// reject the legal form or silently accept this one -- it did the latter,
// compiling this as `h = arr[0]'. With the check here, handle arrays can be
// marshaled for the legal shape.
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
