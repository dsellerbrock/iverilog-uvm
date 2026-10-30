`timescale 1ns/1ns

module main;
  reg time_ref = 0, time_data = 0;
  reg full_ref = 0, full_data = 0;
  reg time_notifier = 0, full_notifier = 0;

  specify
    $timeskew(posedge time_ref, posedge time_data, 2, time_notifier);
    $fullskew(posedge full_ref, posedge full_data, 2, 2, full_notifier);
  endspecify

  initial begin
    #10 time_ref = 1;
    #10 full_ref = 1;
    #5 $display("notifiers %b%b", time_notifier, full_notifier);
    $finish;
  end
endmodule
