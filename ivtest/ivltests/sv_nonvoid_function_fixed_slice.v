// IEEE 1800-2017/2023 7.6, 7.7, 13.4.2 and 13.5.1: a fixed
// unpacked-array slice passed to a value-returning function is an aggregate
// value. Copy-in and copy-out pair elements left-to-right, even when actual
// and formal directions differ. A native unsized formal is a normalized
// dynamic array, not a DPI open array. Automatic output formals start at their
// type default; static output formals retain their value between calls.
module sv_nonvoid_function_fixed_slice;
  int failures;
  int result;

  int fixed_in[1:10];
  int fixed_out[1:10];
  int fixed_io[1:10];

  int dynamic_in[10:1];
  int dynamic_out[10:1];
  int dynamic_io[10:1];

  int static_first[0:3];
  int static_second[0:3];

  class Holder;
    int whole_in[0:3];
    int whole_out[0:3];
    int whole_io[0:3];
  endclass

  Holder holder;

  function automatic int fixed_slice_ports(
      input int value_in[3:0],
      output int value_out[3:0],
      inout int value_io[3:0]);
    for (int ordinal = 0; ordinal < 4; ordinal++) begin
      if (value_in[3-ordinal] != 5003+ordinal) failures++;
      if (value_out[3-ordinal] != 0) failures++;
      if (value_io[3-ordinal] != 6003+ordinal) failures++;
      value_out[3-ordinal] = 7000+ordinal;
      value_io[3-ordinal] = 8000+ordinal;
    end
    return 51;
  endfunction

  function automatic int dynamic_slice_ports(
      input int value_in[],
      output int value_out[],
      inout int value_io[]);
    if (value_in.size() != 4 || $left(value_in) != 0
        || $right(value_in) != 3 || $increment(value_in) != -1)
      failures++;
    if (value_out.size() != 0) failures++;
    if (value_io.size() != 4 || $left(value_io) != 0
        || $right(value_io) != 3 || $increment(value_io) != -1)
      failures++;
    value_out = new[4];
    for (int ordinal = 0; ordinal < 4; ordinal++) begin
      if (value_in[ordinal] != 9008-ordinal) failures++;
      if (value_io[ordinal] != 10008-ordinal) failures++;
      value_out[ordinal] = 11000+ordinal;
      value_io[ordinal] = 12000+ordinal;
    end
    return 91;
  endfunction

  function int retain_fixed(output int value_out[3:0],
                            input bit write_value);
    static int calls;
    calls++;
    if (calls == 1)
      for (int ordinal = 0; ordinal < 4; ordinal++)
        if (value_out[3-ordinal] != 0) failures++;
    if (write_value)
      for (int ordinal = 0; ordinal < 4; ordinal++)
        value_out[3-ordinal] = 13000+ordinal;
    return calls;
  endfunction

  function automatic int whole_property_ports(
      input int value_in[3:0],
      output int value_out[3:0],
      inout int value_io[3:0]);
    for (int ordinal = 0; ordinal < 4; ordinal++) begin
      if (value_in[3-ordinal] != 14000+ordinal) failures++;
      if (value_out[3-ordinal] != 0) failures++;
      if (value_io[3-ordinal] != 14100+ordinal) failures++;
      value_out[3-ordinal] = 14200+ordinal;
      value_io[3-ordinal] = 14300+ordinal;
    end
    return 141;
  endfunction

  initial begin
    foreach (fixed_in[i]) fixed_in[i] = 5000+i;
    foreach (fixed_out[i]) fixed_out[i] = -1;
    foreach (fixed_io[i]) fixed_io[i] = 6000+i;
    result = fixed_slice_ports(fixed_in[3:6], fixed_out[3:6],
                               fixed_io[3:6]);
    if (result != 51) failures++;
    for (int ordinal = 0; ordinal < 4; ordinal++) begin
      if (fixed_out[3+ordinal] != 7000+ordinal) failures++;
      if (fixed_io[3+ordinal] != 8000+ordinal) failures++;
    end
    if (fixed_out[2] != -1 || fixed_out[7] != -1) failures++;
    if (fixed_io[2] != 6002 || fixed_io[7] != 6007) failures++;

    foreach (dynamic_in[i]) dynamic_in[i] = 9000+i;
    foreach (dynamic_out[i]) dynamic_out[i] = -1;
    foreach (dynamic_io[i]) dynamic_io[i] = 10000+i;
    result = dynamic_slice_ports(dynamic_in[8:5], dynamic_out[8:5],
                                 dynamic_io[8:5]);
    if (result != 91) failures++;
    for (int ordinal = 0; ordinal < 4; ordinal++) begin
      if (dynamic_out[8-ordinal] != 11000+ordinal) failures++;
      if (dynamic_io[8-ordinal] != 12000+ordinal) failures++;
    end
    if (dynamic_out[9] != -1 || dynamic_out[4] != -1) failures++;
    if (dynamic_io[9] != 10009 || dynamic_io[4] != 10004) failures++;

    foreach (static_first[i]) static_first[i] = -1;
    foreach (static_second[i]) static_second[i] = -2;
    result = retain_fixed(static_first, 1'b1);
    if (result != 1) failures++;
    result = retain_fixed(static_second, 1'b0);
    if (result != 2) failures++;
    for (int ordinal = 0; ordinal < 4; ordinal++) begin
      if (static_first[ordinal] != 13000+ordinal) failures++;
      if (static_second[ordinal] != 13000+ordinal) failures++;
    end

    holder = new;
    for (int i = 0; i < 4; i++) begin
      holder.whole_in[i] = 14000+i;
      holder.whole_out[i] = -1;
      holder.whole_io[i] = 14100+i;
    end
    result = whole_property_ports(holder.whole_in, holder.whole_out,
                                  holder.whole_io);
    if (result != 141) failures++;
    for (int ordinal = 0; ordinal < 4; ordinal++) begin
      if (holder.whole_out[ordinal] != 14200+ordinal) failures++;
      if (holder.whole_io[ordinal] != 14300+ordinal) failures++;
    end

    if (failures != 0)
      $fatal(1, "nonvoid fixed-array slice/function failures=%0d", failures);
    $display("PASSED");
    $finish(0);
  end
endmodule
