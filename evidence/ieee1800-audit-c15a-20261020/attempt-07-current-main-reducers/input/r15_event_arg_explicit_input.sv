module p;
 event e;
 task trigger_event(input event ev); -> ev; endtask
 initial trigger_event(e);
endmodule
