module sv_packed_select_incdec_bounds;
  logic [7:0] four_state;
  bit [7:0] two_state;
  logic four_result;
  bit two_result;
  logic [3:0] four_part;
  bit [3:0] two_part;
  logic [3:0] unknown_index;
  bit [3:0] two_state_index;
  logic signed [-2:5] ascending;
  logic signed [12:5] nonzero;
  logic signed [3:0] signed_part;
  int calls;

  function automatic int invalid_index(); calls++; return 9; endfunction

  initial begin
    four_state=8'haa; calls=0; four_result=four_state[invalid_index()]++;
    if (four_state!==8'haa || four_result!==1'bx || calls!=1) $fatal(1,"invalid bit");
    four_state=8'haa; unknown_index='x; four_result=++four_state[unknown_index];
    if (four_state!==8'haa || four_result!==1'bx) $fatal(1,"unknown bit");
    four_state=8'haa; four_part=four_state[6+:4]++;
    if (four_state!==8'bxx101010 || four_part!==4'bxx10) $fatal(1,"four-state OOB part");

    two_state=8'haa; two_result=two_state[12]++;
    if (two_state!=8'haa || two_result!=0) $fatal(1,"two-state invalid bit");
    two_state=8'haa; two_state_index='x; two_result=++two_state[two_state_index];
    if (two_state!=8'hab || two_result!=1) $fatal(1,"two-state unknown bit");
    two_state=8'haa; two_part=two_state[6+:4]++;
    if (two_state!=8'hea || two_part!=4'h2) $fatal(1,"two-state OOB part");

    ascending='0; ascending[0]=1; four_result=ascending[0]++;
    if (ascending!=='0 || four_result!==1) $fatal(1,"ascending range");
    nonzero='0; nonzero[10:7]=4'sd7; signed_part=++nonzero[10:7];
    if (nonzero[10:7]!==4'sd8 || signed_part!==-4'sd8) $fatal(1,"signed range");
    $display("PASSED");
  end
endmodule
