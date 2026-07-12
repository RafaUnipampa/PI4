`timescale 1ns/1ps

module tb_q_table;

    reg clk;

    reg [9:0] read_state;
    reg [9:0] write_state;
    reg signed [31:0] write_data;
    reg wr_way0;
    reg wr_way1;

    wire signed [31:0] q0;
    wire signed [31:0] q1;

    q_table dut (
        .clk(clk),
        .read_state(read_state),
        .write_state(write_state),
        .write_data(write_data),
        .wr_way0(wr_way0),
        .wr_way1(wr_way1),
        .q0(q0),
        .q1(q1)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("tb_q_table.vcd");
        $dumpvars(0, tb_q_table);

        clk = 0;
        read_state = 0;
        write_state = 0;
        write_data = 0;
        wr_way0 = 0;
        wr_way1 = 0;

        #10;

        // Teste 1: escrever na via 0 do estado 5
        write_state = 10'd5;
        write_data = 32'd109;
        wr_way0 = 1;
        wr_way1 = 0;

        @(posedge clk);
        #1;

        wr_way0 = 0;
        read_state = 10'd5;
        #1;

        $display("TESTE 1: estado 5");
        $display("q0=%0d q1=%0d", q0, q1);

        if (q0 == 32'd109 && q1 == 32'd0)
            $display("OK: escreveu somente na via 0");
        else
            $display("ERRO: escrita na via 0 falhou");

        // Teste 2: escrever na via 1 do estado 6
        write_state = 10'd6;
        write_data = 32'd114;
        wr_way0 = 0;
        wr_way1 = 1;

        @(posedge clk);
        #1;

        wr_way1 = 0;
        read_state = 10'd6;
        #1;

        $display("TESTE 2: estado 6");
        $display("q0=%0d q1=%0d", q0, q1);

        if (q0 == 32'd0 && q1 == 32'd114)
            $display("OK: escreveu somente na via 1");
        else
            $display("ERRO: escrita na via 1 falhou");

        // Teste 3: confirmar que estado 5 manteve a via 0
        read_state = 10'd5;
        #1;

        $display("TESTE 3: voltando ao estado 5");
        $display("q0=%0d q1=%0d", q0, q1);

        if (q0 == 32'd109 && q1 == 32'd0)
            $display("OK: estado 5 preservado corretamente");
        else
            $display("ERRO: estado 5 foi alterado indevidamente");

        $display("SIMULACAO DA Q-TABLE FINALIZADA.");
        $finish;
    end

endmodule