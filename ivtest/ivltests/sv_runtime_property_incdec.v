module test;
  class C;
    int scalar;
    logic [7:0] logic_values[3:1];
    bit [7:0] bit_values[-1:1];
    real real_values[0:1];
  endclass

  C first, second, handles[2];
  logic signed [127:0] index_value;
  int receiver_calls, index_calls;
  int int_result;
  logic [7:0] logic_result;
  bit [7:0] bit_result;
  real real_result;

  function automatic int select_receiver;
    receiver_calls++; return 0;
  endfunction
  function automatic logic signed [127:0] next_index;
    index_calls++; return index_value;
  endfunction

  initial begin
    first=new; second=new; handles[0]=first; handles[1]=second;
    first.scalar=5; second.scalar=100;
    first.logic_values[1]=8'h10; first.logic_values[2]=8'h20;
    first.logic_values[3]=8'h30;
    first.bit_values[-1]=8'h40; first.bit_values[0]=8'h50;
    first.bit_values[1]=8'h60;
    first.real_values[0]=1.5; first.real_values[1]=2.5;
    #1;

    int_result=first.scalar++;
    if (int_result!==5 || first.scalar!==6) $fatal(1,"scalar postinc");
    int_result=--first.scalar;
    if (int_result!==5 || first.scalar!==5) $fatal(1,"scalar predec");

    receiver_calls=0; index_calls=0; index_value=2;
    logic_result=handles[select_receiver()].logic_values[next_index()]++;
    if (logic_result!==8'h20 || first.logic_values[2]!==8'h21
        || second.scalar!==100 || receiver_calls!==1 || index_calls!==1)
      $fatal(1,"captured receiver/index");

    index_calls=0; index_value=-1;
    bit_result=++first.bit_values[next_index()];
    if (bit_result!==8'h41 || first.bit_values[-1]!==8'h41
        || first.bit_values[0]!==8'h50 || index_calls!==1)
      $fatal(1,"negative range preinc");

    index_calls=0; index_value=1;
    real_result=first.real_values[next_index()]--;
    if (real_result!=2.5 || first.real_values[1]!=1.5 || index_calls!==1)
      $fatal(1,"real property postdec");

    index_calls=0; index_value=128'bx;
    logic_result=first.logic_values[next_index()]++;
    if (logic_result!==8'hxx || first.logic_values[1]!==8'h10
        || first.logic_values[2]!==8'h21 || index_calls!==1)
      $fatal(1,"unknown logic index");
    index_calls=0; index_value=128'sd1<<100;
    bit_result=++first.bit_values[next_index()];
    if (bit_result!==8'h01 || first.bit_values[-1]!==8'h41
        || first.bit_values[0]!==8'h50 || index_calls!==1)
      $fatal(1,"wide bit index");
    index_calls=0; index_value=128'bz;
    real_result=--first.real_values[next_index()];
    if (real_result!=-1.0 || first.real_values[0]!=1.5
        || first.real_values[1]!=1.5 || index_calls!==1)
      $fatal(1,"unknown real index");

    $display("PASSED");
  end
endmodule
