// IEEE 1800-2023 33.6.2 to 33.6.5: the configuration examples, for the
// library structure of lib.map. This file matches no library and is
// compiled into `work'. A test selects one config with -s.

// 33.6.2: always take m from adder.v.
config cfg1;
   design rtlLib.top;
   default liblist aLib rtlLib;
endconfig

// 33.6.2: the gate-level adder and m; top has no gate-level cell.
config cfg2;
   design rtlLib.top;
   default liblist gateLib aLib rtlLib;
endconfig

// 33.6.3: the rtl adder with the gate-level m.
config cfg3;
   design rtlLib.top;
   default liblist aLib rtlLib;
   cell m use gateLib.m;
endconfig

// 33.6.4: top.a2 and its descendants from aLib; liblists are inherited.
config cfg4;
   design rtlLib.top;
   default liblist gateLib rtlLib;
   instance top.a2 liblist aLib;
endconfig : cfg4

// 33.6.5: a config of adder alone, with instance names relative to adder.
config cfg5;
   design aLib.adder;
   default liblist gateLib aLib;
   instance adder.f1 liblist rtlLib;
endconfig

// 33.6.5: top.a2 is configured by cfg5.
config cfg6;
   design rtlLib.top;
   default liblist aLib rtlLib;
   instance top.a2 use work.cfg5:config;
endconfig

// 33.4.1.4: a cell clause with a library selects the instances that are
// about to be bound to that cell.
config cfg7;
   design rtlLib.top;
   default liblist aLib rtlLib;
   cell aLib.m use gateLib.m;
endconfig

// 33.4.1.6: an instance clause is more specific than a cell clause, and a
// use clause without a library takes the library of the parent cell.
config cfg8;
   design rtlLib.top;
   default liblist aLib rtlLib;
   cell m use gateLib.m;
   instance top.a1.f1 use m;
endconfig
