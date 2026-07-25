// M10-1/R7: passing a whole unpacked array of class handles where the formal
// is a single handle is not a legal actual (IEEE 1800-2017 13.5.x) and must
// be rejected.
//
// tgt-vvp used to pass element 0 silently, so this compiled and quietly
// behaved as `takes(arr[0])'.
module object_array_as_handle_arg;
  class C;
    int id;
  endclass

  function automatic int takes(C x);
    return x.id;
  endfunction

  C arr[4];

  initial begin
    for (int i = 0; i < 4; i++) begin
      arr[i] = new;
      arr[i].id = i;
    end
    $display("%0d", takes(arr));   // illegal: whole array as a handle actual
  end
endmodule
