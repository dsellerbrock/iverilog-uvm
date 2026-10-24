parameter logic [7:0] My_DataIn = 8'hFF;

module bus_conn (
    output logic [7:0] dataout,
    input        [7:0] datain = My_DataIn
);
    assign dataout = datain;
endmodule

module bus_connect1 (
    output logic [31:0] dataout,
    input        [7:0] datain
);
    parameter logic [7:0] My_DataIn = 8'h00;

    bus_conn bconn0 (dataout[31:24], 8'h0F);
    bus_conn bconn1 (dataout[23:16]);
    bus_conn bconn2 (dataout[15:8], My_DataIn);
    bus_conn bconn3 (dataout[7:0]);
endmodule

module top;
    logic [31:0] dataout;
    bus_connect1 dut(dataout, 8'h00);
    initial begin
        #1 $display("%08h", dataout);
    end
endmodule
