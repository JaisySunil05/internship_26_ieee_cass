`timescale 1ns / 1ps

module tb_peak_tracker_top;

    localparam integer DIV_RATIO  = 4;
    localparam integer CLK_PERIOD = 10;

    reg         clk;
    reg         rst_n;
    reg  [7:0]  data_in;

    wire [7:0]  peak;
    wire [15:0] interval;
    wire        clk_en_out;

    //--------------------------------------------------
    // DUT
    //--------------------------------------------------
    peak_tracker_top #(
        .DIV_RATIO(DIV_RATIO)
    ) dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .data_in    (data_in),
        .peak       (peak),
        .interval   (interval),
        .clk_en_out (clk_en_out)
    );

    //--------------------------------------------------
    // Clock Generation
    //--------------------------------------------------
    initial clk = 1'b0;

    always #(CLK_PERIOD/2)
        clk = ~clk;

    //--------------------------------------------------
    // Reference Model
    //--------------------------------------------------
    reg [7:0]  exp_peak;
    reg [15:0] exp_interval;
    reg [15:0] exp_timer;

    integer pass_count;
    integer fail_count;

    //--------------------------------------------------
    // Peak Checker
    //--------------------------------------------------
    task check_peak;
        input [7:0] got;
        input [7:0] expected;
        begin
            if (got === expected) begin
                pass_count = pass_count + 1;
                $display("PASS | PEAK     | got=%0d", got);
            end
            else begin
                fail_count = fail_count + 1;
                $display("FAIL | PEAK     | got=%0d expected=%0d",
                         got, expected);
            end
        end
    endtask

    //--------------------------------------------------
    // Interval Checker
    //--------------------------------------------------
    task check_interval;
        input [15:0] got;
        input [15:0] expected;
        begin
            if (got === expected) begin
                pass_count = pass_count + 1;
                $display("PASS | INTERVAL | got=%0d", got);
            end
            else begin
                fail_count = fail_count + 1;
                $display("FAIL | INTERVAL | got=%0d expected=%0d",
                         got, expected);
            end
        end
    endtask

    //--------------------------------------------------
    // Wait for sampling instant
    //--------------------------------------------------
    task wait_one_tick;
        begin
            @(posedge clk_en_out);
            #1;
        end
    endtask

    //--------------------------------------------------
    // Apply sample and verify
    //--------------------------------------------------
    task apply_and_check;
        input [7:0] val;
        begin

            data_in = val;

            wait_one_tick;

            // Reference model
            if (val > exp_peak) begin
                exp_interval = exp_timer;
                exp_peak     = val;
                exp_timer    = 16'd0;
            end
            else begin
                exp_timer = exp_timer + DIV_RATIO;
            end

            #1;

            check_peak(peak, exp_peak);
            check_interval(interval, exp_interval);

        end
    endtask

    //--------------------------------------------------
    // Reset
    //--------------------------------------------------
    task do_reset;
        begin

            rst_n   = 1'b0;
            data_in = 8'd0;

            repeat(4)
                @(posedge clk);

            rst_n = 1'b1;

            exp_peak     = 8'd0;
            exp_interval = 16'd0;
            exp_timer    = 16'd0;

            @(posedge clk_en_out);

        end
    endtask

    //--------------------------------------------------
    // Main Test
    //--------------------------------------------------
    initial begin

        pass_count = 0;
        fail_count = 0;

        do_reset();

        $display("\n=== Peak Tracker Test ===\n");

        // Rising peaks
        apply_and_check(8'd50);
        apply_and_check(8'd100);
        apply_and_check(8'd200);

        // No new peak
        apply_and_check(8'd150);
        apply_and_check(8'd180);
        apply_and_check(8'd199);

        // New peak
        apply_and_check(8'd230);

        // More samples
        apply_and_check(8'd50);
        apply_and_check(8'd230);
        apply_and_check(8'd1);

        // Final peak
        apply_and_check(8'd255);

        $display("\n==============================");
        $display("PASS COUNT = %0d", pass_count);
        $display("FAIL COUNT = %0d", fail_count);
        $display("==============================\n");

        #100;
        $finish;

    end

endmodule