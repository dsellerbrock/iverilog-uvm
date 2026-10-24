timeunit 100ps / 10fs;

module a_dat;
    timeunit 1ms / 1us;
    initial begin
        $display("Simulation time unit: %0d, precision: %0d",
            $timeunit($root), $timeprecision($root));
        $display("Compilation time unit: %0d, precision: %0d",
            $timeunit($unit), $timeprecision($unit));
        $display("a_dat time unit: %0d, precision: %0d",
            $timeunit, $timeprecision);
        $display("b_dat.c1 time unit: %0d, precision: %0d",
            $timeunit(b_dat.c1), $timeprecision(b_dat.c1));
    end
endmodule

`timescale 10 fs / 1 fs
module b_dat;
    c_dat c1 ();
endmodule

`timescale 1 ns / 1 ns
module c_dat;
endmodule
