module sv_packed_select_incdec;
  logic [15:0] value;
  logic bit_result;
  logic [3:0] part_result;
  int calls;

  function automatic int bit_index(input int index);
    calls++;
    return index;
  endfunction

  function automatic int part_base();
    calls++;
    return 4;
  endfunction

  initial begin
    value=16'ha55a; calls=0; bit_result=value[bit_index(1)]++;
    if (value!==16'ha558 || bit_result!==1'b1 || calls!=1)
      $fatal(1,"bit postfix value=%h result=%b calls=%0d",value,bit_result,calls);

    value=16'ha55a; calls=0; bit_result=++value[bit_index(2)];
    if (value!==16'ha55e || bit_result!==1'b1 || calls!=1)
      $fatal(1,"bit prefix value=%h result=%b calls=%0d",value,bit_result,calls);

    value=16'ha55a; calls=0; part_result=value[part_base()+:4]++;
    if (value!==16'ha56a || part_result!==4'h5 || calls!=1)
      $fatal(1,"part postfix value=%h result=%h calls=%0d",value,part_result,calls);

    value=16'ha55a; calls=0; part_result=--value[part_base()+:4];
    if (value!==16'ha54a || part_result!==4'h4 || calls!=1)
      $fatal(1,"part prefix value=%h result=%h calls=%0d",value,part_result,calls);
    $display("PASSED");
  end
endmodule
