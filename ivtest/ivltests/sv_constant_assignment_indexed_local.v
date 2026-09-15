module test;
  function automatic int calc;
    int values[2], index, old;
    values[0]=5; values[1]=7; index=0;
    old=values[index++]++;
    return 1000*index+100*values[0]+10*values[1]+old;
  endfunction
  function automatic logic [127:0] invalid_index;
    logic [31:0] values[2]; int index; logic [31:0] old;
    values[0]=5; values[1]=7; index=2;
    old=values[index++]++;
    return {index,values[0],values[1],old};
  endfunction
  function automatic logic [95:0] wide_index;
    logic [31:0] values[2]; logic [127:0] index; logic [31:0] old;
    values[0]=5; values[1]=7; index=128'd1<<100;
    old=values[index]++;
    return {values[0],values[1],old};
  endfunction
  function automatic int signed_default;
    int values[1], index;
    index=1;
    return values[index]++ < -1;
  endfunction
  localparam int VALUE=calc();
  localparam logic [127:0] INVALID=invalid_index();
  localparam logic [95:0] WIDE=wide_index();
  localparam int SIGNED_DEFAULT=signed_default();
  if (VALUE != 1675) begin: invalid_result
    constant_assignment_indexed_local_result_is_wrong failure();
  end
  if (INVALID !== {32'd3,32'd5,32'd7,32'bx}) begin: invalid_index_result
    constant_assignment_invalid_index_result_is_wrong failure();
  end
  if (WIDE !== {32'd5,32'd7,32'bx}) begin: wide_index_result
    constant_assignment_wide_index_result_is_wrong failure();
  end
  if (SIGNED_DEFAULT !== 0) begin: signed_default_result
    constant_assignment_signed_default_result_is_wrong failure();
  end
endmodule
