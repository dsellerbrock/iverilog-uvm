// IEEE1800-2017/2023 6.16,6.22.3,13.5: string variables require explicit casts.
module sv_fixed_property_output_string_fail;
 class Box;string text[2];logic[15:0] bits[2];endclass
 function automatic int packed_value(output logic[15:0] v);v=16'h4142;return 0;endfunction
 function automatic int string_value(output string v);v="CD";return 0;endfunction
 initial begin
 Box b;int ignored;b=new;
 ignored=packed_value(b.text[0]);
 ignored=string_value(b.bits[0]);
 $display("text=%s bits=%h",b.text[0],b.bits[0]);
 end
endmodule
