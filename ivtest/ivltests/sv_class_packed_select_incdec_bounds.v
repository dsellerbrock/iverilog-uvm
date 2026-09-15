module sv_class_packed_select_incdec_bounds;
  class holder; logic [7:0] four; bit [7:0] two; endclass
  holder object; logic logic_bit_result; bit bit_result; logic [3:0] logic_part_result; bit [3:0] bit_part_result;
  logic signed [31:0] offset; logic [63:0] unsigned_offset;
  initial begin object=new;
    object.four=8'haa; logic_bit_result=object.four[12]++;
    if(object.four!==8'haa || logic_bit_result!==1'bx) $fatal(1,"4-state invalid bit mismatch");
    object.two=8'haa; bit_result=object.two[12]++;
    if(object.two!=8'haa || bit_result!=0) $fatal(1,"2-state invalid bit mismatch");
    object.four=8'haa; logic_part_result=object.four[6+:4]++;
    if(object.four!==8'bxx101010 || logic_part_result!==4'bxx10) $fatal(1,"4-state partial OOB mismatch");
    object.two=8'haa; bit_part_result=object.two[6+:4]++;
    if(object.two!=8'hea || bit_part_result!=4'h2) $fatal(1,"2-state partial OOB mismatch");
    object.four=8'haa; offset=-2; logic_part_result=object.four[offset+:4]++;
    if(logic_part_result!==4'b10xx || object.four!==8'b101010xx) $fatal(1,"negative partial overlap");
    object.four=8'haa; offset='x; logic_part_result=++object.four[offset+:4];
    if(logic_part_result!==4'bxxxx || object.four!==8'haa) $fatal(1,"unknown base suppressed");
    object.two=8'haa; bit_part_result=++object.two[offset+:4];
    if(bit_part_result!==1 || object.two!==8'haa) $fatal(1,"two-state invalid prefix");
    object.four=8'haa; unsigned_offset='1; logic_part_result=object.four[unsigned_offset+:4]++;
    if(logic_part_result!==4'bxxxx || object.four!==8'haa) $fatal(1,"unsigned high index");
    $display("PASSED"); end
endmodule
