`default_nettype none
`timescale 1ns/1ps

module tb();

reg clk;
reg rst_n;
reg ena;

reg [7:0] ui_in;
reg [7:0] uio_in;

wire [7:0] uo_out;
wire [7:0] uio_out;
wire [7:0] uio_oe;


tt_um_anomaly_detector dut (
    .ui_in(ui_in),
    .uo_out(uo_out),
    .uio_in(uio_in),
    .uio_out(uio_out),
    .uio_oe(uio_oe),
    .ena(ena),
    .clk(clk),
    .rst_n(rst_n)
);


initial clk=0;
always #5 clk=~clk;



initial begin

    $dumpfile("tb.fst");
    $dumpvars(0,tb);


    // initial values
    ena=0;
    rst_n=0;

    ui_in=0;

    // threshold
    uio_in=20;


    // reset
    #20;

    rst_n=1;
    ena=1;


    // normal samples
    #10 ui_in=50;
    #10 ui_in=52;
    #10 ui_in=49;
    #10 ui_in=51;


    // anomaly
    #10 ui_in=200;


    // wait
    #50;


    $finish;

end


endmodule
