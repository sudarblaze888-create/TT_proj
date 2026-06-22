`default_nettype none

module tt_um_anomaly_detector (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    // 4-sample circular window registers
    reg [7:0] w0, w1, w2, w3;
    reg [1:0] wr_ptr;
    reg [2:0] count;
    reg [7:0] mean;
    reg       alert;
    reg       ready;

    // Absolute difference: input vs current mean (before update)
    wire [7:0] diff = (ui_in >= mean) ? (ui_in - mean) : (mean - ui_in);

    // New sum: replace the slot at wr_ptr with ui_in
    wire [9:0] sum_next =
        (wr_ptr == 2'd0) ? ({2'b0,ui_in} + {2'b0,w1} + {2'b0,w2} + {2'b0,w3}) :
        (wr_ptr == 2'd1) ? ({2'b0,w0} + {2'b0,ui_in} + {2'b0,w2} + {2'b0,w3}) :
        (wr_ptr == 2'd2) ? ({2'b0,w0} + {2'b0,w1} + {2'b0,ui_in} + {2'b0,w3}) :
                           ({2'b0,w0} + {2'b0,w1} + {2'b0,w2} + {2'b0,ui_in});

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w0     <= 8'd0;
            w1     <= 8'd0;
            w2     <= 8'd0;
            w3     <= 8'd0;
            wr_ptr <= 2'd0;
            count  <= 3'd0;
            mean   <= 8'd0;
            alert  <= 1'b0;
            ready  <= 1'b0;
        end else if (ena) begin
            // Write incoming sample
            case (wr_ptr)
                2'd0: w0 <= ui_in;
                2'd1: w1 <= ui_in;
                2'd2: w2 <= ui_in;
                2'd3: w3 <= ui_in;
            endcase

            // Advance circular pointer
            if (wr_ptr == 2'd3)
                wr_ptr <= 2'd0;
            else
                wr_ptr <= wr_ptr + 2'd1;

            // Count samples up to 4
            if (count < 3'd4)
                count <= count + 3'd1;

            // Once window full: update mean, check alert
            if (count >= 3'd3) begin
                ready <= 1'b1;
                mean  <= sum_next[9:2];           // divide by 4
                alert <= (diff > uio_in);         // compare vs threshold
            end else begin
                ready <= 1'b0;
                alert <= 1'b0;
            end
        end
    end

    assign uo_out[0]   = alert;
    assign uo_out[1]   = ready;
    assign uo_out[7:2] = mean[7:2];

endmodule
