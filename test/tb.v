`timescale 1ns/1ps
`default_nettype none

module tb;
    reg  clk, rst_n, ena;
    reg  [7:0] ui_in, uio_in;
    wire [7:0] uo_out, uio_out, uio_oe;

    tt_um_anomaly_detector dut (
        .ui_in(ui_in), .uo_out(uo_out),
        .uio_in(uio_in), .uio_out(uio_out), .uio_oe(uio_oe),
        .ena(ena), .clk(clk), .rst_n(rst_n)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    task send_sample;
        input [7:0] val;
        begin
            ui_in = val;
            @(posedge clk); #1;
            $display("IN=%0d READY=%b ALERT=%b mean_hi=%0d",
                     val, uo_out[1], uo_out[0], uo_out[7:2]);
        end
    endtask

    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);
        rst_n = 0; ena = 1; ui_in = 0; uio_in = 8'd5;
        repeat(3) @(posedge clk);
        rst_n = 1; @(posedge clk);
        send_sample(8'd10);
        send_sample(8'd12);
        send_sample(8'd11);
        send_sample(8'd13);
        send_sample(8'd12);
        send_sample(8'd40);  // spike → ALERT expected
        send_sample(8'd12);
        $finish;
    end
endmodule
