module wide_part_select_vpi;
  logic [7:0] value = 8'ha5;
  longint signed_base = 64'h1_0000_0000;

  initial begin
    #1;
    $wide_pv_test(value[64'h1_0000_0000 +: 4],
                  value[signed_base +: 4], value[-2 +: 4], value[2 +: 4]);
    #1 value[4] = ~value[4];
    #1 value[0] = ~value[0];
    #1 value[7] = ~value[7];
    #1 $wide_pv_done;
  end
endmodule
