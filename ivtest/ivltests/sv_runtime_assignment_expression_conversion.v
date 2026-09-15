module test;
  logic [3:0] input4;
  logic signed [7:0] input8;
  logic [127:0] input128;
  bit [3:0] plain, compound, arithmetic, shifted, nested, zplain;
  bit signed [7:0] signed_value;
  bit [127:0] wide;
  int atom;
  logic [3:0] four_state;
  logic [7:0] plain_result, compound_result, arithmetic_result;
  logic [7:0] shifted_result, nested_result, z_result;
  logic signed [15:0] signed_result;
  logic [127:0] wide_result;
  logic [31:0] atom_result;
  logic [3:0] four_result;
  int rhs_calls;

  function automatic logic [3:0] rhs_once;
    rhs_calls++;
    return input4;
  endfunction

  initial begin
    input4=4'bx101;
    input8=8'b1x00_x000;
    input128={32{4'bx101}};
    #1;
    plain_result=(plain=rhs_once());
    compound=4'h3;
    compound_result=(compound|=input4);
    arithmetic=4'h3;
    arithmetic_result=(arithmetic+=input4);
    shifted=4'hf;
    shifted_result=(shifted<<=2'bz1);
    z_result=(zplain=4'bz10z);
    nested_result=(nested=(plain=input4));
    signed_result=(signed_value=input8);
    wide_result=(wide=input128);
    atom_result=(atom={32{1'bx}});
    four_result=(four_state=input4);

    if (rhs_calls!==1 || plain!==4'h5 || plain_result!==8'h05
        || compound!==4'h7 || compound_result!==8'h07
        || arithmetic!==0 || arithmetic_result!==0
        || shifted!==0 || shifted_result!==0
        || zplain!==4'h4 || z_result!==8'h04
        || nested!==4'h5 || nested_result!==8'h05
        || signed_value!==-8'sh80 || signed_result!==-16'sh80
        || wide!=={32{4'h5}} || wide_result!=={32{4'h5}}
        || atom!==0 || atom_result!==0
        || four_state!==4'bx101 || four_result!==4'bx101)
      $fatal(1,"conversion calls=%0d %h/%h %h/%h %h/%h %h/%h %h/%h %h/%h %h/%h %h %h %h/%h",
             rhs_calls,plain,plain_result,compound,compound_result,
             arithmetic,arithmetic_result,shifted,shifted_result,zplain,z_result,
             nested,nested_result,
             signed_value,signed_result,wide,wide_result,
             atom,four_state,four_result);
    $display("PASSED");
  end
endmodule
