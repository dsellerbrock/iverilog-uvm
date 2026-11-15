// IEEE 1800-2023 33.4.2: it is an error for an instance clause to name an
// instance within a hierarchy that another config specifies.
config bot;
   design bot;
   instance bot.a1 liblist work;
endconfig

config top;
   design top;
   instance top.b use bot:config;
   instance top.b.a1 liblist work; // ERROR: top.b is configured by bot
endconfig

module top;
   bot b();
endmodule

module bot;
   leaf a1();
endmodule

module leaf;
endmodule
