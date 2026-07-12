`timescale 1ns/1ps

module tb_cache_hierarchy;

    reg clk;
    reg rst;
    reg req;
    reg [15:0] addr;

    wire done;
    wire l1_hit;
    wire l2_hit;
    wire mem_access;

    wire [31:0] total_access_count;
    wire [31:0] l1_hit_count;
    wire [31:0] l1_miss_count;
    wire [31:0] l2_hit_count;
    wire [31:0] mem_access_count;
    wire [31:0] qlearning_call_count;

    cache_hierarchy_l1_lru_l2_ql dut (
        .clk(clk),
        .rst(rst),
        .req(req),
        .addr(addr),

        .done(done),
        .l1_hit(l1_hit),
        .l2_hit(l2_hit),
        .mem_access(mem_access),

        .total_access_count(total_access_count),
        .l1_hit_count(l1_hit_count),
        .l1_miss_count(l1_miss_count),
        .l2_hit_count(l2_hit_count),
        .mem_access_count(mem_access_count),
        .qlearning_call_count(qlearning_call_count)
    );

    // Clock de 10 ns -> 100 MHz na simulacao funcional
    always #5 clk = ~clk;

    // ============================================================
    // Reset do sistema
    // ============================================================

    task reset_system;
        begin
            req  <= 1'b0;
            addr <= 16'h0000;
            rst  <= 1'b1;

            repeat (4) begin
                @(posedge clk);
                #1;
            end

            rst <= 1'b0;

            repeat (2) begin
                @(posedge clk);
                #1;
            end
        end
    endtask

    // ============================================================
    // Realiza um acesso a hierarquia
    // ============================================================

    task access_addr;
        input [15:0] a;

        integer wait_cycles;

        begin
            wait_cycles = 0;

            @(posedge clk);
            #1;
            addr <= a;
            req  <= 1'b1;

            @(posedge clk);
            #1;
            req <= 1'b0;

            while ((done == 1'b0) && (wait_cycles < 300)) begin
                @(posedge clk);
                #1;
                wait_cycles = wait_cycles + 1;
            end

            if (wait_cycles >= 300) begin
                $display("ERRO: timeout esperando done para addr=%h", a);
            end else begin
                $display("addr=%h | L1_hit=%b | L2_hit=%b | Mem=%b | total=%0d | L1_hits=%0d | L1_misses=%0d | L2_hits=%0d | Mem_count=%0d | Q_calls=%0d",
                         a,
                         l1_hit,
                         l2_hit,
                         mem_access,
                         total_access_count,
                         l1_hit_count,
                         l1_miss_count,
                         l2_hit_count,
                         mem_access_count,
                         qlearning_call_count);
            end

            @(posedge clk);
            #1;
        end
    endtask

    // ============================================================
    // Imprime resumo do trace
    // ============================================================

    task print_summary;
        input [8*32-1:0] trace_name;

        begin
            $display("\n===== RESUMO: %0s =====", trace_name);
            $display("Total de acessos       = %0d", total_access_count);
            $display("Hits na L1             = %0d", l1_hit_count);
            $display("Misses na L1           = %0d", l1_miss_count);
            $display("Hits na L2             = %0d", l2_hit_count);
            $display("Acessos a memoria      = %0d", mem_access_count);
            $display("Chamadas ao Q-Learning = %0d", qlearning_call_count);

            if (total_access_count > 0) begin
                $display("Taxa de hit L1         = %0d%%", (l1_hit_count * 100) / total_access_count);
                $display("Taxa de acesso memoria = %0d%%", (mem_access_count * 100) / total_access_count);
            end

            $display("========================================\n");
        end
    endtask

    // ============================================================
    // Simulacao principal
    // ============================================================

    initial begin
        $dumpfile("cache_hierarchy_traces.vcd");
        $dumpvars(0, tb_cache_hierarchy);

        clk  = 1'b0;
        rst  = 1'b0;
        req  = 1'b0;
        addr = 16'h0000;

        // ============================================================
        // TRACE 1: BOA LOCALIDADE
        //
        // L1 final:
        // OFFSET_BITS = 5 -> bloco de 32 bytes
        //
        // Enderecos como 0000, 0004, 0008 e 0010 ficam no mesmo bloco.
        // Esperado: apos o primeiro acesso, os demais tendem a bater na L1.
        // ============================================================

        $display("\n\n==============================");
        $display("TRACE 1 - BOA LOCALIDADE");
        $display("==============================");

        reset_system();

        access_addr(16'h0000);
        access_addr(16'h0004);
        access_addr(16'h0008);
        access_addr(16'h0010);

        access_addr(16'h0000);
        access_addr(16'h0004);
        access_addr(16'h0008);
        access_addr(16'h0010);

        access_addr(16'h0000);
        access_addr(16'h0004);

        #30;
        print_summary("BOA LOCALIDADE");

        // ============================================================
        // TRACE 2: CONFLITO FORTE
        //
        // L2 final:
        // OFFSET_BITS = 6
        // INDEX_BITS  = 6
        //
        // Para cair no mesmo conjunto da L2:
        //
        // distancia = 2^(OFFSET_BITS + INDEX_BITS)
        // distancia = 2^(6 + 6)
        // distancia = 4096 decimal = 0x1000
        //
        // Como a L2 tem 8 vias:
        // os 8 primeiros enderecos preenchem as 8 vias do conjunto.
        // O 9o endereco deve acionar o Q-Learning.
        // ============================================================

        $display("\n\n==============================");
        $display("TRACE 2 - CONFLITO FORTE");
        $display("==============================");

        reset_system();

        access_addr(16'h0000); // ocupa uma via da L2 no conjunto 0
        access_addr(16'h1000); // mesma posicao de conjunto da L2, tag diferente
        access_addr(16'h2000);
        access_addr(16'h3000);
        access_addr(16'h4000);
        access_addr(16'h5000);
        access_addr(16'h6000);
        access_addr(16'h7000);

        // Aqui o conjunto da L2 ja deve estar cheio.
        // Este acesso deve chamar o Q-Learning.
        access_addr(16'h8000);

        // Mais conflitos no mesmo conjunto
        access_addr(16'h9000);
        access_addr(16'hA000);

        // Reacessos para observar comportamento apos substituicoes
        access_addr(16'h0000);
        access_addr(16'h1000);
        access_addr(16'h8000);

        #30;
        print_summary("CONFLITO FORTE");

        // ============================================================
        // TRACE 3: MISTO
        //
        // Mistura:
        // - acessos no mesmo bloco para gerar hits na L1;
        // - acessos que conflitam na L1;
        // - reacessos que podem aparecer na L2.
        //
        // Para a L1:
        // OFFSET_BITS = 5
        // INDEX_BITS  = 6
        //
        // Enderecos separados por 0x0800 caem no mesmo conjunto da L1.
        // ============================================================

        $display("\n\n==============================");
        $display("TRACE 3 - MISTO");
        $display("==============================");

        reset_system();

        // Boa localidade dentro do mesmo bloco da L1
        access_addr(16'h0000);
        access_addr(16'h0004);
        access_addr(16'h0008);

        // Conflitos na L1, pois 0000, 0800 e 1000 caem no mesmo conjunto da L1
        access_addr(16'h0800);
        access_addr(16'h1000);

        // Reacesso a bloco antigo: pode virar miss na L1 e hit na L2
        access_addr(16'h0000);
        access_addr(16'h0004);

        // Mais mistura de conflito e localidade
        access_addr(16'h1800);
        access_addr(16'h1000);
        access_addr(16'h1004);

        access_addr(16'h0800);
        access_addr(16'h0000);

        #30;
        print_summary("MISTO");

        #50;
        $finish;
    end

endmodule