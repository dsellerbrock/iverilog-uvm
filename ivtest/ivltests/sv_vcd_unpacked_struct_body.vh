module `VCD_TEST_MODULE;
  typedef struct {
    int x;
    logic [1:0] y;
  } payload_t;
  payload_t payload;

  initial begin
    payload.x = 0;
    payload.y = 0;
    $dumpfile("sv_vcd_unpacked_struct.vcd");
    $dumpvars(0, `VCD_TEST_MODULE);
    #1 payload.x = 3;
    payload.y = 2;
    #1 $dumpflush;
    $system("tail -n +4 sv_vcd_unpacked_struct.vcd");
    #1 $finish;
  end
endmodule
