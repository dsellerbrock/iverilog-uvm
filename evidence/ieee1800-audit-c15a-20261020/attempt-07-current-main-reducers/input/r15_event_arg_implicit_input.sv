module p;
 event e;
 task trigger_event(event ev); -> ev; endtask
 initial trigger_event(e);
endmodule
