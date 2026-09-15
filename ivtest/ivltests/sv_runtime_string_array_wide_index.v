module test;
  string values[-1:1], got;
  int ints[-1:1];
  logic [127:0] unsigned_index;
  logic signed [127:0] signed_index;
  int calls;

  function automatic logic [127:0] next_unsigned;
    calls++; return unsigned_index;
  endfunction
  function automatic string automatic_read(input logic [127:0] index);
    string local_values[3:1];
    local_values[1]="one"; local_values[2]="two";
    local_values[3]="three";
    return local_values[index];
  endfunction

  initial begin
    values[-1]="minus"; values[0]="zero"; values[1]="plus";
    ints[-1]=11; ints[0]=22; ints[1]=33;
    #1;
    signed_index=-1;
    got=values[signed_index];
    if (got!="minus") $fatal(1,"signed negative index");

    calls=0; unsigned_index='1;
    got=values[next_unsigned()];
    if (got!="" || calls!==1) $fatal(1,"unsigned all-ones index");
    if (ints[unsigned_index]!==0) $fatal(1,"two-state invalid read");
    ints[unsigned_index]=99;
    if (ints[-1]!==11 || ints[0]!==22 || ints[1]!==33)
      $fatal(1,"invalid write changed neighbor");

    unsigned_index=128'd1<<100;
    if (values[unsigned_index]!="") $fatal(1,"wide index");
    unsigned_index=128'bx;
    if (values[unsigned_index]!="") $fatal(1,"unknown index");
    unsigned_index=128'bz;
    if (values[unsigned_index]!="") $fatal(1,"high-impedance index");
    if (automatic_read(128'd2)!="two"
        || automatic_read(128'd1<<100)!="")
      $fatal(1,"automatic string array");
    $display("PASSED");
  end
endmodule
