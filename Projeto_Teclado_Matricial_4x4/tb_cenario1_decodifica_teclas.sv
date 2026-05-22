`timescale 1ns/1ps
`define DEBUG 1

// ============================================================
// Cenário 1 — Decodificação do Teclado
//
// Objetivo: verificar se o circuito converte corretamente cada
// combinação linha/coluna para o valor BCD correspondente.
//
// Método:
//   - Sorteia aleatoriamente um dígito (0–9)
//   - Simula o scan matricial: responde ao lin_matriz do DUT
//     injetando a col_matriz da tecla desejada
//   - Pressiona * para confirmar a entrada
//   - Aguarda borda de subida de digitos_valid
//   - Verifica os 4 bits menos significativos do barramento
//     (digitos_value.digits[0]) contra o valor BCD esperado
// ============================================================

module tb_cenario1_decodifica_teclas;

    // ----------------------------------------------------------
    // Parâmetros de tempo
    // ----------------------------------------------------------
    localparam integer DEBOUNCE_CYCLES = 110;  // > 100 pulsos de debounce da spec
    localparam integer VALID_TIMEOUT   = 250;  // max ciclos aguardando digitos_valid
    localparam integer META_COBERTURA  = 5;    // acertos mínimos por dígito

    // ----------------------------------------------------------
    // Sinais de interface
    // ----------------------------------------------------------
    logic        clk;
    logic        rst;
    logic        enable;
    logic [3:0]  col_matriz;
    logic [3:0]  lin_matriz;
    senhaPac_t   digitos_value;
    logic        digitos_valid;

    // ----------------------------------------------------------
    // DUT
    // ----------------------------------------------------------
    decodificador_de_teclado dut (
        .clk          (clk),
        .rst          (rst),
        .enable       (enable),
        .col_matriz   (col_matriz),
        .lin_matriz   (lin_matriz),
        .digitos_value(digitos_value),
        .digitos_valid(digitos_valid)
    );

    // ----------------------------------------------------------
    // Clock: período de 1 ns
    // ----------------------------------------------------------
    initial clk = 0;
    always #0.5 clk = ~clk;

    // ----------------------------------------------------------
    // Modelo de teclado matricial
    //
    // O DUT ativa uma linha por vez (lin_matriz, active-low).
    // O testbench responde com a coluna correspondente à tecla
    // "pressionada" quando a linha correta é ativada, ou com
    // 4'b1111 (nenhuma tecla) para as demais linhas.
    // ----------------------------------------------------------
    logic        key_active;
    logic [3:0]  key_lin_exp;
    logic [3:0]  key_col_exp;

    always @(*) begin
        if (key_active && lin_matriz == key_lin_exp)
            col_matriz = key_col_exp;
        else
            col_matriz = 4'b1111;
    end

    // ----------------------------------------------------------
    // Tabela de coordenadas (LINHA, COLUNA) conforme especificação
    //
    //  Tecla | BCD  | LINHA | COLUNA
    //  ------|------|-------|-------
    //    0   | 0x0  | 1110  | 1011
    //    1   | 0x1  | 0111  | 0111
    //    2   | 0x2  | 0111  | 1011
    //    3   | 0x3  | 0111  | 1101
    //    4   | 0x4  | 1011  | 0111
    //    5   | 0x5  | 1011  | 1011
    //    6   | 0x6  | 1011  | 1101
    //    7   | 0x7  | 1101  | 0111
    //    8   | 0x8  | 1101  | 1011
    //    9   | 0x9  | 1101  | 1101
    //    *   | 0xA  | 1110  | 0111   (confirmação)
    // ----------------------------------------------------------
    function automatic void coord_digito(
        input  logic [3:0] d,
        output logic [3:0] lin,
        output logic [3:0] col
    );
        case (d)
            4'h0: begin lin = 4'b1110; col = 4'b1011; end
            4'h1: begin lin = 4'b0111; col = 4'b0111; end
            4'h2: begin lin = 4'b0111; col = 4'b1011; end
            4'h3: begin lin = 4'b0111; col = 4'b1101; end
            4'h4: begin lin = 4'b1011; col = 4'b0111; end
            4'h5: begin lin = 4'b1011; col = 4'b1011; end
            4'h6: begin lin = 4'b1011; col = 4'b1101; end
            4'h7: begin lin = 4'b1101; col = 4'b0111; end
            4'h8: begin lin = 4'b1101; col = 4'b1011; end
            4'h9: begin lin = 4'b1101; col = 4'b1101; end
            default: begin lin = 4'bxxxx; col = 4'bxxxx; end
        endcase
    endfunction

    // ----------------------------------------------------------
    // Task: pressiona um dígito (0–9) e aguarda o debounce
    // ----------------------------------------------------------
    task automatic pressionar_digito(input logic [3:0] d);
        logic [3:0] l, c;
        coord_digito(d, l, c);
        if (`DEBUG)
            $display("[KB] Pressionando digito %0d  (LIN=%b, COL=%b)", d, l, c);
        key_lin_exp = l;
        key_col_exp = c;
        key_active  = 1;
        repeat(DEBOUNCE_CYCLES) @(posedge clk);
        key_active  = 0;
        if (`DEBUG) $display("[KB] Digito %0d liberado", d);
    endtask

    // ----------------------------------------------------------
    // Task: pressiona * para confirmar a entrada
    //   * → LINHA=1110, COLUNA=0111
    // ----------------------------------------------------------
    task automatic pressionar_asterisco;
        if (`DEBUG) $display("[KB] Pressionando * (confirmacao)");
        key_lin_exp = 4'b1110;
        key_col_exp = 4'b0111;
        key_active  = 1;
        repeat(DEBOUNCE_CYCLES) @(posedge clk);
        key_active  = 0;
        if (`DEBUG) $display("[KB] Tecla * liberada");
    endtask

    // ----------------------------------------------------------
    // Task: aguarda borda de subida de digitos_valid com timeout
    //
    // timed_out = 0 → válido recebido
    // timed_out = 1 → timeout esgotado
    // ----------------------------------------------------------
    task automatic aguardar_valid(output logic timed_out);
        timed_out = 1;
        fork
            begin : bloco_valid
                @(posedge digitos_valid);
                timed_out = 0;
            end
            begin : bloco_timeout
                repeat(VALID_TIMEOUT) @(posedge clk);
            end
        join_any
        disable fork;
    endtask

    // ----------------------------------------------------------
    // Cobertura: contagem de acertos por dígito
    // ----------------------------------------------------------
    integer hit_count[10];

    function automatic bit cobertura_completa();
        for (int i = 0; i <= 9; i++)
            if (hit_count[i] < META_COBERTURA) return 0;
        return 1;
    endfunction

    task automatic exibir_cobertura;
        integer cobertos;
        cobertos = 0;
        $display("\n=== COBERTURA  (meta: %0d acertos por digito) ===", META_COBERTURA);
        for (int i = 0; i <= 9; i++) begin
            $display("  Digito %0d : %0d/%0d  %s",
                i, hit_count[i], META_COBERTURA,
                hit_count[i] >= META_COBERTURA ? "[OK     ]" : "[PENDENTE]");
            if (hit_count[i] >= META_COBERTURA) cobertos++;
        end
        $display("  Total: %0d/10  (%.0f%%)", cobertos, cobertos * 10.0);
    endtask

    // ----------------------------------------------------------
    // Contadores globais
    // ----------------------------------------------------------
    integer total_ok;
    integer total_fail;
    integer iteracao;

    // ----------------------------------------------------------
    // Task: um ciclo completo de teste
    //   sorteia dígito → pressiona → confirma → verifica saída
    // ----------------------------------------------------------
    task automatic executar_ciclo;
        logic [3:0] digito_rand;
        logic [3:0] digito_obtido;
        logic       timed_out;

        digito_rand = $urandom_range(0, 9);
        iteracao++;

        $display("\n--- Ciclo %0d  |  Digito sorteado: %0d ---", iteracao, digito_rand);

        // Pressiona o dígito numérico
        pressionar_digito(digito_rand);

        // Pausa mínima entre teclas
        repeat(10) @(posedge clk);

        // Confirma a entrada com *
        pressionar_asterisco();

        // Aguarda sinal de dados prontos
        aguardar_valid(timed_out);

        if (timed_out) begin
            $display("[FALHA] Timeout: digitos_valid nao subiu em %0d ciclos", VALID_TIMEOUT);
            total_fail++;
            return;
        end

        // Verifica os 4 bits menos significativos do barramento
        digito_obtido = digitos_value.digits[0];

        if (digito_obtido === digito_rand) begin
            $display("[SUCESSO] Digito %0d decodificado corretamente  (esperado=0x%X  obtido=0x%X)",
                     digito_rand, digito_rand, digito_obtido);
            total_ok++;
            hit_count[digito_rand]++;
        end else begin
            $display("[FALHA]   Digito %0d decodificado errado         (esperado=0x%X  obtido=0x%X)",
                     digito_rand, digito_rand, digito_obtido);
            total_fail++;
        end

        // Aguarda barramento voltar ao estado ocioso (digitos_valid desce)
        @(negedge digitos_valid);
        repeat(20) @(posedge clk);
    endtask

    // ----------------------------------------------------------
    // Fluxo principal de simulação
    // ----------------------------------------------------------
    integer seed;

    initial begin
        if (!$value$plusargs("seed=%d", seed))
            seed = $urandom;
        $srandom(seed);
        $display("=== SEMENTE: %0d ===", seed);

        $dumpfile("tb_cenario1.vcd");
        $dumpvars(0, tb_cenario1_decodifica_teclas);

        foreach (hit_count[i]) hit_count[i] = 0;
        total_ok   = 0;
        total_fail = 0;
        iteracao   = 0;
        key_active = 0;

        // Reset inicial
        enable = 0;
        rst    = 1;
        repeat(5) @(posedge clk);
        rst    = 0;
        enable = 1;
        repeat(5) @(posedge clk);

        $display("=== CENARIO 1: DECODIFICACAO DO TECLADO ===");
        $display("=== Meta: %0d acertos por digito (0-9) ===", META_COBERTURA);

        // Executa ciclos até atingir cobertura completa
        while (!cobertura_completa()) begin
            executar_ciclo();
            exibir_cobertura();
        end

        // Relatório final
        $display("\n================================================");
        $display("=== CENARIO 1: COBERTURA COMPLETA ===");
        $display("  Ciclos executados : %0d", iteracao);
        $display("  Sucesso           : %0d", total_ok);
        $display("  Falha             : %0d", total_fail);
        exibir_cobertura();

        repeat(10) @(posedge clk);
        $finish;
    end

endmodule
