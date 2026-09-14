module test;
  int ints[2], int_result;
  logic [7:0] logics[2], logic_result;
  real reals[2], real_result;
  initial begin
    ints[0]=5; ints[1]=7;
    logics[0]=8'h15; logics[1]=8'h27;
    reals[0]=1.5; reals[1]=2.5;
    #1;
    int_result=ints[2]++;
    logic_result=++logics[2];
    real_result=reals[2]--;
    if (int_result!==0 || logic_result!==8'hxx || real_result!=0.0
        || ints[0]!==5 || ints[1]!==7
        || logics[0]!==8'h15 || logics[1]!==8'h27
        || reals[0]!=1.5 || reals[1]!=2.5)
      $fatal(1,"static invalid %0d/%h/%f",int_result,logic_result,real_result);
    $display("PASSED");
  end
endmodule
