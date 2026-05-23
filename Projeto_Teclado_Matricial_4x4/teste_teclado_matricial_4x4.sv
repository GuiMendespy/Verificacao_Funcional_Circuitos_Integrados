`timescale 1ns/1ps
`define DEBUG 1

module tb_teclado;

    logic clk, rst, enable;
    logic [3:0] col_matriz;
    logic [3:0] lin_matriz;
    senhaPac_t digitos_value;
    logic digitos_valid;

    decodificador_de_teclado dut (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .col_matriz(col_matriz),
        .lin_matriz(lin_matriz),
        .digitos_value(digitos_value),
        .digitos_valid(digitos_valid)
    );

    initial clk = 0;
    always #0.5 clk = ~clk;

    bit [1:0] num;
    integer hit_count [10];

    // ================================================================
    // Utilitarios comuns
    // ================================================================

    // Retorna {lin[7:4], col[3:0]} para o digito d (Icarus nao suporta output em functions)
    function automatic logic [7:0] get_coords(input logic [3:0] d);
        case (d)
            4'h0: return 8'b1110_1011;
            4'h1: return 8'b0111_0111;
            4'h2: return 8'b0111_1011;
            4'h3: return 8'b0111_1101;
            4'h4: return 8'b1011_0111;
            4'h5: return 8'b1011_1011;
            4'h6: return 8'b1011_1101;
            4'h7: return 8'b1101_0111;
            4'h8: return 8'b1101_1011;
            4'h9: return 8'b1101_1101;
            default: return 8'bxxxx_xxxx;
        endcase
    endfunction

    // Aguarda o DUT varrer a linha correta e injeta a coluna por 115 ciclos
    task automatic pressionar_tecla(input logic [3:0] d);
        logic [7:0] coords;
        coords = get_coords(d);
        while (lin_matriz !== coords[7:4]) @(posedge clk);
        col_matriz = coords[3:0];
        repeat(115) @(posedge clk);
        col_matriz = 4'b1111;
        repeat(10) @(posedge clk);
    endtask

    // Pressiona tecla * para confirmar: LINHA=1110, COL=0111
    task automatic pressionar_asterisco;
        while (lin_matriz !== 4'b1110) @(posedge clk);
        col_matriz = 4'b0111;
        repeat(115) @(posedge clk);
        col_matriz = 4'b1111;
        repeat(10) @(posedge clk);
    endtask

    // Reset padrao entre cenarios
    task fazer_reset;
        col_matriz = 4'b1111;
        rst    = 1;
        enable = 0;
        repeat(5) @(posedge clk);
        rst    = 0;
        enable = 1;
        repeat(5) @(posedge clk);
    endtask

    // ================================================================
    // CENARIO 1 — Decodificacao do teclado (original)
    // ================================================================

    function bit cobertura_completa();
        for (int i = 0; i <= 9; i++)
            if (hit_count[i] < 5) return 0;
        return 1;
    endfunction

    task exibir_cobertura;
        integer cobertos;
        cobertos = 0;
        $display("\n=== RELATORIO DE COBERTURA (meta: 5 hits cada) ===");
        for (int i = 0; i <= 9; i++) begin
            $display("  Digito %0d: %0d/5  %s", i, hit_count[i],
                     hit_count[i] >= 5 ? "[COBERTO]" : "[PENDENTE]");
            if (hit_count[i] >= 5) cobertos++;
        end
        $display("  Total: %0d/10 digitos cobertos (%.0f%%)", cobertos, cobertos * 10.0);
    endtask

    task gerar_num_aleatorio(output bit [3:0] numero_out);
        numero_out = $random(seed) & 3;
    endtask

    task varrer_coluna;
        gerar_num_aleatorio(num);
        case(num)
            4'd0    : col_matriz = 4'b0111;
            4'd1    : col_matriz = 4'b1011;
            4'd2    : col_matriz = 4'b1101;
            default : col_matriz = 4'b1111;
        endcase
        if (`DEBUG) $display("[DEBUG TB] Coluna injetada: %b (num=%0d)", col_matriz, num);
    endtask

    function bit [3:0] descobrir_digito_esperado();
        bit [3:0] digito_local;
        digito_local = 4'hF;
        if (`DEBUG) $display("[DEBUG TB] Linha: %b | Coluna: %b", lin_matriz, col_matriz);
        if (lin_matriz == 4'b0111) begin
            if      (col_matriz == 4'b0111) digito_local = 4'h1;
            else if (col_matriz == 4'b1011) digito_local = 4'h2;
            else if (col_matriz == 4'b1101) digito_local = 4'h3;
        end
        else if (lin_matriz == 4'b1011) begin
            if      (col_matriz == 4'b0111) digito_local = 4'h4;
            else if (col_matriz == 4'b1011) digito_local = 4'h5;
            else if (col_matriz == 4'b1101) digito_local = 4'h6;
        end
        else if (lin_matriz == 4'b1101) begin
            if      (col_matriz == 4'b0111) digito_local = 4'h7;
            else if (col_matriz == 4'b1011) digito_local = 4'h8;
            else if (col_matriz == 4'b1101) digito_local = 4'h9;
        end
        else if (lin_matriz == 4'b1110) begin
            if      (col_matriz == 4'b0111) digito_local = 4'hA;
            else if (col_matriz == 4'b1011) digito_local = 4'h0;
            else if (col_matriz == 4'b1101) digito_local = 4'hB;
        end
        return digito_local;
    endfunction

    task aplicar_debounce;
        $display("[DEBOUNCE] Segurando por 110 ciclos...");
        repeat(110) @(posedge clk);
        $display("[DEBOUNCE] Concluido.");
    endtask

    task teste_decodificar_teclado;
        bit [3:0] esperado;
        $display("[START] Iniciando teste de decodificacao...");
        col_matriz = 4'b1111;
        rst = 1; enable = 1;
        repeat(5) @(posedge clk);
        rst = 0;
        if (`DEBUG) $display("[DEBUG TB] Reset finalizado.");
        gerar_num_aleatorio(num);
        repeat(num + 5) @(posedge clk);
        varrer_coluna();
        aplicar_debounce();
        repeat(5) @(posedge clk);
        esperado = descobrir_digito_esperado();
        if (`DEBUG) $display("[DEBUG TB] Esperado: %X | Obtido: %X", esperado, digitos_value.digits[0]);
        if (digitos_value.digits[0] === esperado)
            $display("[SUCESSO] Decodificacao correta: %X", esperado);
        else
            $display("[FALHA] Esperado: %X, Obtido: %X", esperado, digitos_value.digits[0]);
        if (esperado <= 4'h9)
            hit_count[esperado]++;
    endtask

    // ================================================================
    // CENARIO 2 — Shift do barramento
    // Digita 0-9 duas vezes (20 digitos), verifica o array completo,
    // depois insere um 21o digito e verifica o deslocamento correto.
    // ================================================================

    task automatic teste_shift_barramento;
        logic [3:0]  digito_extra;
        logic [3:0]  esperado_k;
        logic [3:0]  obtido_k;
        logic [79:0] flat;       // cast para indexacao variavel
        integer erros;
        integer k;

        $display("\n================================================");
        $display("=== CENARIO 2: SHIFT DO BARRAMENTO ===");
        fazer_reset();

        // Pressionando 20 digitos (0,1,...,9,0,1,...,9)
        $display("[C2] Digitando sequencia 0-9 duas vezes (20 digitos)...");
        for (int i = 0; i < 20; i++) begin
            pressionar_tecla(i % 10);
            if (`DEBUG) $display("[C2] Digitado %0d  |  digits[0]=%0X", i%10, digitos_value.digits[0]);
        end

        // Sequencia pressionada: indice i (0..19), valor = i%10
        //   posicao k no barramento = valor do indice (19-k) = (19-k)%10
        $display("[C2] Verificando as 20 posicoes do barramento...");
        flat   = digitos_value;
        erros  = 0;
        for (k = 0; k < 20; k++) begin
            esperado_k = (19 - k) % 10;
            obtido_k   = flat[k*4 +: 4];
            if (obtido_k !== esperado_k) begin
                $display("[FALHA] digits[%0d]: esperado=0x%X  obtido=0x%X", k, esperado_k, obtido_k);
                erros++;
            end
        end
        if (erros == 0)
            $display("[SUCESSO] Barramento com 20 posicoes correto.");
        else
            $display("[FALHA] %0d erros no barramento completo.", erros);

        // Insere um 21o digito aleatorio e verifica o shift
        digito_extra = $urandom_range(0, 9);
        $display("[C2] Inserindo 21o digito (%0d) — verificando shift...", digito_extra);
        pressionar_tecla(digito_extra);

        // Apos o shift:
        //   digits[0]   = digito_extra (novo)
        //   digits[k]   = antigo digits[k-1] = (19-(k-1))%10 = (20-k)%10  para k>=1
        //   digits[19]  = (20-19)%10 = 1   (o original '0' em digits[19] foi descartado)
        flat   = digitos_value;
        erros  = 0;
        if (flat[0*4 +: 4] !== digito_extra) begin
            $display("[FALHA] Shift: digits[0] esperado=%0X  obtido=%0X", digito_extra, flat[0*4 +: 4]);
            erros++;
        end
        for (k = 1; k < 20; k++) begin
            esperado_k = (20 - k) % 10;
            obtido_k   = flat[k*4 +: 4];
            if (obtido_k !== esperado_k) begin
                $display("[FALHA] Shift digits[%0d]: esperado=0x%X  obtido=0x%X", k, esperado_k, obtido_k);
                erros++;
            end
        end
        if (erros == 0)
            $display("[SUCESSO] Shift do barramento verificado corretamente.");
        else
            $display("[FALHA] %0d erros apos o shift.", erros);

        pressionar_asterisco();
        repeat(20) @(posedge clk);
    endtask

    // ================================================================
    // CENARIO 3 — Debounce
    // Simula oscilacoes rapidas (press/release < 100 ciclos cada) e
    // verifica que nenhum digito e registrado durante o ruido.
    // Em seguida, realiza um pressionamento estavel (>100 ciclos) e
    // verifica que exatamente um digito e registrado.
    // ================================================================

    task automatic teste_debounce;
        logic [3:0] tecla;
        logic [7:0] coords;
        logic [3:0] l, c;

        $display("\n================================================");
        $display("=== CENARIO 3: DEBOUNCE ===");
        fazer_reset();

        tecla  = $urandom_range(1, 9);
        coords = get_coords(tecla);
        l      = coords[7:4];
        c      = coords[3:0];
        $display("[C3] Tecla alvo: %0d  (LIN=%b, COL=%b)", tecla, l, c);

        // Fase 1: ruido de bouncing — press/release a cada 2 ciclos, 40 repeticoes
        // Cada ciclo de press nao atinge os 100 do debounce → nenhuma tecla registrada
        $display("[C3] Gerando ruido de bouncing (40 ciclos de oscilacao)...");
        repeat(40) begin
            // Injeta coluna sem esperar linha correta (simula ruido mecanico)
            col_matriz = c;
            repeat(2) @(posedge clk);
            col_matriz = 4'b1111;
            repeat(2) @(posedge clk);
        end

        // Aguarda DUT retornar ao estado leitura
        repeat(15) @(posedge clk);

        if (digitos_value.digits[0] !== 4'hF)
            $display("[FALHA] Ruido registrado como tecla: digits[0]=0x%X (esperado 0xF)", digitos_value.digits[0]);
        else
            $display("[SUCESSO] Ruido de bouncing ignorado corretamente (digits[0]=F).");

        // Fase 2: pressionamento estavel por 115 ciclos (> 100 do debounce)
        $display("[C3] Pressionando tecla %0d de forma estavel...", tecla);
        while (lin_matriz !== l) @(posedge clk);
        col_matriz = c;
        repeat(115) @(posedge clk);
        col_matriz = 4'b1111;
        repeat(15) @(posedge clk);

        if (digitos_value.digits[0] === tecla)
            $display("[SUCESSO] Tecla %0d registrada apos estabilizacao.", tecla);
        else
            $display("[FALHA] Tecla nao registrada: digits[0]=0x%X (esperado=0x%X)", digitos_value.digits[0], tecla);

        pressionar_asterisco();
        repeat(20) @(posedge clk);
    endtask

    // ================================================================
    // CENARIO 4 — Repeticao automatica da tecla
    // Mantém uma tecla pressionada por 3000 ciclos (>2s se 1s=1000 clk)
    // e verifica se o sistema repete automaticamente a entrada.
    // Nota: se o design nao implementar repeat, o teste reporta AVISO.
    // ================================================================

    task automatic teste_repeticao_tecla;
        logic [3:0] tecla;
        logic [7:0] coords;
        logic [3:0] l, c;

        $display("\n================================================");
        $display("=== CENARIO 4: REPETICAO AUTOMATICA DE TECLA ===");
        fazer_reset();

        tecla  = $urandom_range(1, 9);
        coords = get_coords(tecla);
        l      = coords[7:4];
        c      = coords[3:0];
        $display("[C4] Mantendo tecla %0d pressionada por 3000 ciclos (>2s simulados)...", tecla);

        // Aguarda linha correta e segura a tecla por 3000 ciclos
        while (lin_matriz !== l) @(posedge clk);
        col_matriz = c;
        repeat(3000) @(posedge clk);
        col_matriz = 4'b1111;
        repeat(20) @(posedge clk);

        if (`DEBUG) begin
            $display("[DEBUG C4] digits[0]=0x%X  digits[1]=0x%X", digitos_value.digits[0], digitos_value.digits[1]);
        end

        // Se repeticao implementada: digits[0] e digits[1] devem ser iguais a tecla
        if (digitos_value.digits[0] === tecla && digitos_value.digits[1] === tecla) begin
            $display("[SUCESSO] Repeticao automatica detectada.");
            $display("          digits[0]=%0X  digits[1]=%0X", digitos_value.digits[0], digitos_value.digits[1]);
        end else if (digitos_value.digits[0] === tecla) begin
            $display("[AVISO] Tecla registrada apenas 1 vez. Repeticao automatica NAO implementada.");
            $display("        digits[0]=%0X (tecla)  digits[1]=%0X (deveria ser %0X)",
                     digitos_value.digits[0], digitos_value.digits[1], tecla);
        end else begin
            $display("[FALHA] Tecla nao registrada: digits[0]=0x%X (esperado 0x%X)", digitos_value.digits[0], tecla);
        end

        pressionar_asterisco();
        repeat(20) @(posedge clk);
    endtask

    // ================================================================
    // CENARIO 5 — Confirmacao com tecla *
    // Digita N digitos aleatorios, captura o barramento antes do *,
    // pressiona * e verifica:
    //   (a) digitos_valid sobe em no maximo 120 ciclos apos o *
    //   (b) o ultimo digito digitado estava correto no barramento
    // ================================================================

    task automatic teste_confirmacao_asterisco;
        localparam integer N = 5;
        logic [3:0] digitados [N];
        logic [3:0] ultimo_capturado;
        integer ciclos;
        integer ok_timing, ok_dados;

        $display("\n================================================");
        $display("=== CENARIO 5: CONFIRMACAO COM * ===");
        fazer_reset();

        // Digita N digitos aleatorios
        $display("[C5] Digitando %0d teclas aleatorias...", N);
        for (int i = 0; i < N; i++) begin
            digitados[i] = $urandom_range(0, 9);
            pressionar_tecla(digitados[i]);
            if (`DEBUG) $display("[C5] Digitou %0d  digits[0]=%0X", digitados[i], digitos_value.digits[0]);
        end

        // Captura o ultimo digito do barramento ANTES de pressionar *
        ultimo_capturado = digitos_value.digits[0];
        ok_dados = (ultimo_capturado === digitados[N-1]);
        $display("[C5] Ultimo digitado: %0d | Capturado em digits[0]: 0x%X  %s",
                 digitados[N-1], ultimo_capturado, ok_dados ? "[OK]" : "[ERRO]");

        // Pressiona * e mede ciclos ate digitos_valid subir (maximo 120)
        $display("[C5] Pressionando * e aguardando digitos_valid (max 120 ciclos)...");
        while (lin_matriz !== 4'b1110) @(posedge clk);
        col_matriz = 4'b0111;  // *

        ciclos     = 0;
        ok_timing  = 0;
        while (!digitos_valid && ciclos < 200) begin
            @(posedge clk);
            ciclos++;
        end
        col_matriz = 4'b1111;

        if (digitos_valid) begin
            ok_timing = (ciclos <= 120);
            if (ok_timing)
                $display("[SUCESSO] digitos_valid ativado em %0d ciclos (limite: 120).", ciclos);
            else
                $display("[FALHA]   digitos_valid demorou %0d ciclos (limite: 120).", ciclos);
        end else begin
            $display("[FALHA] Timeout: digitos_valid nao subiu em 200 ciclos.");
        end

        if (ok_dados && ok_timing)
            $display("[CENARIO 5] PASSOU.");
        else
            $display("[CENARIO 5] FALHOU (dados=%0s, timing=%0s).",
                     ok_dados ? "OK" : "ERRO", ok_timing ? "OK" : "ERRO");

        repeat(30) @(posedge clk);
    endtask

    // ================================================================
    // Bloco principal
    // ================================================================
    integer seed;

    initial begin
        if (!$value$plusargs("seed=%d", seed))
            seed = 42;
        void'($random(seed));
        $display("=== SEMENTE ALEATORIA: %0d ===", seed);

        $dumpfile("teste_teclado.vcd");
        $dumpvars(0, tb_teclado);

        // ------ Cenario 1: Decodificacao do teclado ------
        $display("\n================================================");
        $display("=== CENARIO 1: DECODIFICACAO DO TECLADO ===");
        $display("=== Meta: 5 hits por digito (0-9) ===");
        foreach (hit_count[i]) hit_count[i] = 0;

        while (!cobertura_completa()) begin
            $display("\n------------------------------------------------");
            teste_decodificar_teclado();
            exibir_cobertura();
            repeat(50) @(posedge clk);
        end

        $display("\n=== CENARIO 1: COBERTURA COMPLETA! ===");
        exibir_cobertura();

        // ------ Cenario 2: Shift do barramento ------
        teste_shift_barramento();

        // ------ Cenario 3: Debounce ------
        teste_debounce();

        // ------ Cenario 4: Repeticao automatica ------
        teste_repeticao_tecla();

        // ------ Cenario 5: Confirmacao com * ------
        teste_confirmacao_asterisco();

        $display("\n================================================");
        $display("=== FIM DA SIMULACAO ===");
        repeat(10) @(posedge clk);
        $finish;
    end

endmodule
