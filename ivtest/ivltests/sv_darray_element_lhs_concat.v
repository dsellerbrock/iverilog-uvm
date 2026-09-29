module test;
  byte unsigned data[];
  bit [3:0] ep = 4'ha;
  bit [27:0] seq_id = 28'hbcdef12;
  int rhs_calls;

  function automatic bit [31:0] payload();
    rhs_calls++;
    return {ep, seq_id};
  endfunction

  initial begin
    data = new[5];
    data[4] = 8'h55;
    {data[3], data[2], data[1], data[0]} = payload();
    if (rhs_calls != 1 ||
        {data[3], data[2], data[1], data[0]} !== 32'habcdef12 ||
        data[4] !== 8'h55)
      $fatal(1, "wrong dynamic-array concat assignment");
    $display("PASSED");
  end
endmodule
