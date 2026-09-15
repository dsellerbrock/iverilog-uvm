module test;
  int ints[3:1], ir;
  bit [7:0] bits[-1:1], br;
  logic [7:0] logics[3:1], lr;
  real reals[3:1], rr;
  int matrix[1:0][2:1], mr;
  logic signed [127:0] index_value;
  int index_calls, outer_calls, inner_calls;

  function automatic logic signed [127:0] next_index;
    index_calls++; return index_value;
  endfunction
  function automatic int outer_index;
    outer_calls++; return 1;
  endfunction
  function automatic int inner_index;
    inner_calls++; return 2;
  endfunction
  function automatic int recursive(input int value);
    int local_values[2], index;
    index=0; local_values[0]=value;
    return value ? local_values[index++]++ + recursive(value-1) : 0;
  endfunction

  initial begin
    ints[1]=10; ints[2]=20; ints[3]=30;
    bits[-1]=8'h10; bits[0]=8'h20; bits[1]=8'h30;
    logics[1]=8'h40; logics[2]=8'h50; logics[3]=8'h60;
    reals[1]=1.5; reals[2]=2.5; reals[3]=3.5;
    matrix[1][2]=9; matrix[1][1]=8; matrix[0][2]=7; matrix[0][1]=6;
    #1;

    index_value=2; index_calls=0; ir=ints[next_index()]++;
    if (ir!==20 || ints[2]!==21 || index_calls!==1) $fatal(1,"int postinc");
    index_value=3; index_calls=0; ir=--ints[next_index()];
    if (ir!==29 || ints[3]!==29 || index_calls!==1) $fatal(1,"int predec");
    index_value=-1; index_calls=0; br=++bits[next_index()];
    if (br!==8'h11 || bits[-1]!==8'h11 || bits[0]!==8'h20
        || index_calls!==1) $fatal(1,"negative range bit preinc");
    index_value=1; index_calls=0; br=bits[next_index()]--;
    if (br!==8'h30 || bits[1]!==8'h2f || index_calls!==1)
      $fatal(1,"bit postdec");
    index_value=1; index_calls=0; lr=logics[next_index()]++;
    if (lr!==8'h40 || logics[1]!==8'h41 || index_calls!==1)
      $fatal(1,"logic postinc");
    index_value=2; index_calls=0; rr=--reals[next_index()];
    if (rr!=1.5 || reals[2]!=1.5 || index_calls!==1) $fatal(1,"real predec");

    index_value=128'sd1<<32; index_calls=0; br=++bits[next_index()];
    if (br!==1 || bits[-1]!==8'h11 || bits[0]!==8'h20 || bits[1]!==8'h2f
        || index_calls!==1) $fatal(1,"wide bit index");
    index_value=(128'sd1<<32)+1; index_calls=0; rr=++reals[next_index()];
    if (rr!=1.0 || reals[1]!=1.5 || reals[2]!=1.5 || reals[3]!=3.5
        || index_calls!==1) $fatal(1,"wide real index");
    index_value=128'bx; index_calls=0; lr=logics[next_index()]++;
    if (lr!==8'hxx || logics[1]!==8'h41 || index_calls!==1)
      $fatal(1,"unknown logic index");

    outer_calls=0; inner_calls=0; mr=matrix[outer_index()][inner_index()]++;
    if (mr!==9 || matrix[1][2]!==10 || matrix[1][1]!==8
        || matrix[0][2]!==7 || outer_calls!==1 || inner_calls!==1)
      $fatal(1,"multidimensional index");
    if (recursive(3)!==6) $fatal(1,"automatic recursive array");
    $display("PASSED");
  end
endmodule
