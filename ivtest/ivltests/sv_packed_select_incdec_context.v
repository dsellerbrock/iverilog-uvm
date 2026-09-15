module sv_packed_select_incdec_context;
  logic signed [3:0] scalar;
  logic [7:0] carrier;
  logic [1:0] narrow;
  logic [7:0] wide;
  int result;

  function automatic logic signed [3:0] increment_return();
    increment_return=7;
    result=++increment_return;
  endfunction

  function automatic logic [15:0] increment_selected_return(
      input logic [15:0] seed, output logic [3:0] old_value);
    increment_selected_return=seed;
    old_value=increment_selected_return[4+:4]++;
  endfunction

  initial begin
    scalar=-1; result=scalar++;
    if (result!=-1 || scalar!==0) $fatal(1,"signed postfix context");
    scalar=7; result=++scalar;
    if (result!=-8 || scalar!==4'b1000) $fatal(1,"signed prefix overflow context");
    carrier=8'haf; result=++carrier[3:0];
    if (result!=0 || carrier!==8'ha0) $fatal(1,"selected wrap before context");
    carrier=8'ha5; narrow=carrier[3:0]++;
    if (carrier!==8'ha6 || narrow!==2'b01) $fatal(1,"narrow context");
    carrier=8'ha5; wide=++carrier[3:0];
    if (carrier!==8'ha6 || wide!==8'h06) $fatal(1,"wide context");
    if (increment_return()!==4'b1000 || result!=-8) $fatal(1,"return context");
    begin
      logic [15:0] return_value;
      logic [3:0] old_value;
      return_value=increment_selected_return(16'ha55a,old_value);
      if (return_value!==16'ha56a || old_value!==4'h5)
        $fatal(1,"selected return context");
    end
    $display("PASSED");
  end
endmodule
