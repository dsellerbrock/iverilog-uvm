module sv_array_packed_select_incdec_scopes;
  typedef logic [7:0] array_t[0:1];
  logic [7:0] values[-1:0][3:2];
  int first_calls, second_calls, part_calls;

  function automatic int first(); first_calls++; return -1; endfunction
  function automatic int second(); second_calls++; return 2; endfunction
  function automatic int part(); part_calls++; return 4; endfunction
  function automatic array_t make(input logic [7:0] seed, output logic [3:0] old);
    make='{seed,8'h5a};
    old=make[0][3:0]++;
  endfunction

  initial begin
    logic [3:0] result, old1, old2;
    array_t array1, array2;
    values='{'{8'h12,8'ha5},'{8'h34,8'h56}};
    result=++values[first()][second()][part()+:4];
    if (result!==4'hb || values[-1][2]!==8'hb5 || values[-1][3]!==8'h12 ||
        values[0][3]!==8'h34 || values[0][2]!==8'h56 ||
        first_calls!=1 || second_calls!=1 || part_calls!=1)
      $fatal(1,"multidimensional identity or evaluation count");

    array1=make(8'ha5,old1); array2=make(8'hc3,old2);
    if (array1[0]!==8'ha6 || array1[1]!==8'h5a || old1!==4'h5 ||
        array2[0]!==8'hc4 || array2[1]!==8'h5a || old2!==4'h3)
      $fatal(1,"automatic return-array update");
    array1[0]=0;
    if (array2[0]!==8'hc4) $fatal(1,"automatic return arrays alias");
    $display("PASSED");
  end
endmodule
