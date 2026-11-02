`timescale 1ns/1ps

module issue1561_buf(input a, output y);
    assign y = a;
endmodule

module issue1561_sdf_port_netdelay;
    reg port_src = 0;
    reg net_src = 0;
    wire port_wire;
    wire link;
    wire port_out;
    wire net_out1;
    wire net_out2;

    issue1561_buf port_src_inst(.a(port_src), .y(port_wire));
    issue1561_buf port_load_inst(.a(port_wire), .y(port_out));
    issue1561_buf net_src_inst(.a(net_src), .y(link));
    issue1561_buf net_load_inst1(.a(link), .y(net_out1));
    issue1561_buf net_load_inst2(.a(link), .y(net_out2));

    initial begin
        $sdf_annotate("ivltests/issue1561_sdf_port_netdelay.sdf", issue1561_sdf_port_netdelay);
        $monitor("%0t %b %b %b", $time, port_out, net_out1, net_out2);
        #10 port_src = 1;
            net_src = 1;
        #0 if (port_out !== 0 || net_out1 !== 0 || net_out2 !== 0)
            $fatal(1, "SDF interconnect delay was not applied");
        #3 if (port_out === 1 && net_out1 === 1 && net_out2 === 1)
            $display("PASSED");
        else
            $fatal(1, "SDF interconnect load did not update at 13 ns");
        #7 $finish;
    end
endmodule
