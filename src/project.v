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

    reg [7:0] w0, w1, w2, w3;
    reg [1:0] wr_ptr;
    reg [2:0] count;
    reg [7:0] mean;
    reg       alert;
    reg       ready;

    // Compute new sum combinatorially (replaces the slot being written)
    wire [9:0] new_sum =
        (wr_ptr == 2'd0) ? ({2'b0,ui_in} + {2'b0,w1} + {2'b0,w2} + {2'b0,w3}) :
        (wr_ptr == 2'd1) ? ({2'b0,w0} + {2'b0,ui_in} + {2'b0,w2} + {2'b0,w3}) :
        (wr_ptr == 2'd2) ? ({2'b0,w0} + {2'b0,w1} + {2'b0,ui_in} + {2'b0,w3}) :
                           ({2'b0,w0} + {2'b0,w1} + {2'b0,w2} + {2'b0,ui_in});

    wire [7:0] new_mean = new_sum[9:2]; // divide by 4

    // Absolute diff: new input vs OLD mean (catches spike immediately)
    wire [8:0] diff = ({1'b0,ui_in} >= {1'b0,mean})
                    ? ({1'b0,ui_in} - {1'b0,mean})
                    : ({1'b0,mean}  - {1'b0,ui_in});

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w0 <= 0; w1 <= 0; w2 <= 0; w3 <= 0;
            wr_ptr <= 0; count <= 0;
            mean <= 0; alert <= 0; ready <= 0;
        end else if (ena) begin
            case (wr_ptr)
                2'd0: w0 <= ui_in;
                2'd1: w1 <= ui_in;
                2'd2: w2 <= ui_in;
                2'd3: w3 <= ui_in;
            endcase
            wr_ptr <= (wr_ptr == 2'd3) ? 2'd0 : wr_ptr + 2'd1;
            if (count < 3'd4) count <= count + 3'd1;

            if (count >= 3'd3) begin
                ready <= 1'b1;
                mean  <= new_mean;
                alert <= (diff > {1'b0, uio_in});
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
