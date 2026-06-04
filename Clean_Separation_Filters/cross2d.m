clear; clc; close all;
origFormat = get(0, 'Format');  % per formato tabelle
format shortG;                  

%% ========================================================================
% 1. CONFIG
%% ========================================================================
fprintf('Caricamento dati in corso...\n');
load('02_taskPreferenceTable_3grids.mat', 'taskPreferenceTable', 'signal', 'fs');
decompFile = "C:\Users\Charlie XD\Documents\AAAUNIVERSITAAAAAAAAAAAA'\Tesi\Motoneuron_Synergies_Driven_Gesture_Prediction\data_conc_subj1_trial_1_10_13\signal_mov10_mov13_trial1_trial2_filt_for_muedit.mat_decomp";
fprintf('Generazione mappa di corrispondenza filtri da: %s\n', decompFile);
sig_decomp = load(decompFile);

MU_Index_Map = struct();
for grid_idx = 1:double(sig_decomp.signal.ngrid)
    active_ids = find(~cellfun(@isempty, sig_decomp.signal.Dischargetimes(grid_idx, :)));
    MU_Index_Map.(sprintf('Grid_%d', grid_idx)).Original_MU_IDs = active_ids;
end

dataFolder = "final_MU_sets_crosscorr";
plotFolder = 'muap_plots_crosscorr2d';
if ~exist(dataFolder, 'dir'), mkdir(dataFolder); end
if ~exist(plotFolder, 'dir'), mkdir(plotFolder); end

channelsPerGrid = 64;
window_ms = [-10 10];
preSamp  = round(abs(window_ms(1)) / 1000 * fs);
postSamp = round(window_ms(2) / 1000 * fs);
t_axis   = (-preSamp : postSamp) / fs * 1000;
topK_corr   = 10;

%THRESHOLDS
R_threshold_mean    = 0.70;  % Scarta la MU se la media di tutti i suoi casi Intra-MU è SOTTO lo 0.70
Duplicate_threshold = 0.80;  % Scarta come duplicato se la MEDIA Inter-MU dei trial validi è SOPRA lo 0.80

seg.pinch_T1 = [1 9999];
seg.pinch_T2 = [10000 20599];
seg.hand_T1  = [20600 30879];
seg.hand_T2  = [30880 40719];

T = taskPreferenceTable;
T.TaskClass = string(T.TaskClass);

% Inizializzazione colonne metriche INTRA-MU SPLITTATE per la TABELLA 1
T.R2D_Pinch             = nan(height(T), 1); 
T.R2D_Hand              = nan(height(T), 1); 
T.R2D_P1_H2             = nan(height(T), 1); 
T.R2D_P2_H1             = nan(height(T), 1); 
T.R2D_P1_H1             = nan(height(T), 1); 
T.R2D_P2_H2             = nan(height(T), 1); 
T.R2D_Global_Pinch_Hand = nan(height(T), 1); 
T.Mean_All_Cases        = nan(height(T), 1); 

T.FinalSet_New          = repmat("Pending", height(T), 1); 
T.KeepMU_New            = false(height(T), 1);
totalRows = height(T);

fprintf('Fase 1: Estrazione Metriche INTRA-MU e Generazione Plot Diagnostici su %d unità...\n', totalRows);

% Manteniamo i plot nascosti a schermo durante l'elaborazione per velocizzare MATLAB
set(0, 'DefaultFigureVisible', 'off');
MU_Collector = struct();

%% ========================================================================
% 1A: Estrazione R2D, Forme d'onda e Generazione Immagini Diagnostiche (2x2)
%% ========================================================================
for row = 1:totalRows
    g  = T.Grid(row);
    mu = T.MU(row);
    
    chStart = (g-1)*channelsPerGrid + 1;
    chEnd   = g*channelsPerGrid;
    EMG_grid = double(signal.data(chStart:chEnd, :));
    
    if mu > size(signal.Dischargetimes, 2) || isempty(signal.Dischargetimes{g, mu})
        continue; 
    end
    
    spk_all = sort(signal.Dischargetimes{g, mu}(:));
    spikes_p_T1 = spk_all(spk_all >= seg.pinch_T1(1) & spk_all <= seg.pinch_T1(2));
    spikes_p_T2 = spk_all(spk_all >= seg.pinch_T2(1) & spk_all <= seg.pinch_T2(2));
    spikes_h_T1 = spk_all(spk_all >= seg.hand_T1(1)  & spk_all <= seg.hand_T1(2));
    spikes_h_T2 = spk_all(spk_all >= seg.hand_T2(1)  & spk_all <= seg.hand_T2(2));
    
    spikes_p_all = [spikes_p_T1; spikes_p_T2];
    spikes_h_all = [spikes_h_T1; spikes_h_T2]; 
    
    MUAP_p_T1  = compute_sta(EMG_grid, spikes_p_T1, preSamp, postSamp);
    MUAP_p_T2  = compute_sta(EMG_grid, spikes_p_T2, preSamp, postSamp);
    MUAP_h_T1  = compute_sta(EMG_grid, spikes_h_T1, preSamp, postSamp);
    MUAP_h_T2  = compute_sta(EMG_grid, spikes_h_T2, preSamp, postSamp);
    MUAP_p_all = compute_sta(EMG_grid, spikes_p_all, preSamp, postSamp);
    MUAP_h_all = compute_sta(EMG_grid, spikes_h_all, preSamp, postSamp);
    
    % Salva i MUAP per il successivo controllo Inter-MU
    MU_Collector.(sprintf('Grid_%d', g)).P_T1(:,:,mu)  = MUAP_p_T1;
    MU_Collector.(sprintf('Grid_%d', g)).P_T2(:,:,mu)  = MUAP_p_T2;
    MU_Collector.(sprintf('Grid_%d', g)).H_T1(:,:,mu)  = MUAP_h_T1;
    MU_Collector.(sprintf('Grid_%d', g)).H_T2(:,:,mu)  = MUAP_h_T2;
    MU_Collector.(sprintf('Grid_%d', g)).P_All(:,:,mu) = MUAP_p_all;
    MU_Collector.(sprintf('Grid_%d', g)).H_All(:,:,mu) = MUAP_h_all;
    
    p2p_global = max(MUAP_h_all,[],2) - min(MUAP_h_all,[],2);
    if any(isnan(p2p_global))
        p2p_global = max(MUAP_p_all,[],2) - min(MUAP_p_all,[],2);
    end
    if all(isnan(p2p_global)), continue; end
    
    [~, sortedChans] = sort(p2p_global, 'descend');
    topChans = sortedChans(1:min(topK_corr, numel(sortedChans)));
    best_ch = topChans(1); % Canale con ampiezza massima
    
    r_P1_P2 = compute_muap_xcorr2D(MUAP_p_T1, MUAP_p_T2, topChans);
    r_H1_H2 = compute_muap_xcorr2D(MUAP_h_T1, MUAP_h_T2, topChans);
    r_P1_H2 = compute_muap_xcorr2D(MUAP_p_T1, MUAP_h_T2, topChans);
    r_P2_H1 = compute_muap_xcorr2D(MUAP_p_T2, MUAP_h_T1, topChans);
    r_P1_H1 = compute_muap_xcorr2D(MUAP_p_T1, MUAP_h_T1, topChans);
    r_P2_H2 = compute_muap_xcorr2D(MUAP_p_T2, MUAP_h_T2, topChans);
    r_Global = compute_muap_xcorr2D(MUAP_p_all, MUAP_h_all, topChans);
    
    T.R2D_Pinch(row)              = r_P1_P2;
    T.R2D_Hand(row)               = r_H1_H2;
    T.R2D_P1_H2(row)              = r_P1_H2;
    T.R2D_P2_H1(row)              = r_P2_H1;
    T.R2D_P1_H1(row)              = r_P1_H1;
    T.R2D_P2_H2(row)              = r_P2_H2;
    T.R2D_Global_Pinch_Hand(row)  = r_Global;
    
    all_intra_corrs = [r_P1_P2, r_H1_H2, r_P1_H2, r_P2_H1, r_P1_H1, r_P2_H2, r_Global];
    mean_score = mean(all_intra_corrs, 'omitnan');
    T.Mean_All_Cases(row)         = mean_score;

    %% =====================================================================
    % GENERAZIONE GRAFICO DIAGNOSTICO ORIGINALE AGGIORNATO (Layout 2x2)
    %% =====================================================================
    fig = figure('Color', 'w', 'Units', 'pixels', 'Position', [100, 100, 1200, 850]);
    
    % Palette fissa a 10 colori per matchare i canali top tra Pinch e Hand
    colors_top10 = lines(min(10, numel(topChans)));
    
    % --- Pannello 1: PINCH - Confronto Inter-Trial sul canale migliore ---
    subplot(2, 2, 1); hold on;
    if ~any(isnan(MUAP_p_T1(:))), plot(t_axis, MUAP_p_T1(best_ch, :), 'Color', [0.2 0.6 0.8], 'LineWidth', 2); end
    if ~any(isnan(MUAP_p_T2(:))), plot(t_axis, MUAP_p_T2(best_ch, :), 'Color', [0.9 0.4 0.1], 'LineWidth', 1.5, 'LineStyle', '--'); end
    grid on; title(sprintf('PINCH: Allineamento Trial (Ch Best %d, R2D = %.2f)', best_ch, r_P1_P2));
    xlabel('Tempo (ms)'); ylabel('Ampiezza (\muV)');
    legend({'Trial 1', 'Trial 2'}, 'Location', 'best');
    axis tight;
    
    % --- Pannello 2: PINCH - Sovrapposizione morfologica dei 10 canali top ---
    subplot(2, 2, 2); hold on;
    if ~any(isnan(MUAP_p_all(:)))
        for tc_idx = 1:numel(topChans)
            ch = topChans(tc_idx);
            plot(t_axis, MUAP_p_all(ch, :), 'Color', colors_top10(tc_idx, :), 'LineWidth', 1.2);
        end
    end
    grid on; title('PINCH: Coerenza Forme d''Onda (10 Canali Top Matched)');
    xlabel('Tempo (ms)'); ylabel('Ampiezza (\muV)');
    axis tight;
    
    % --- Pannello 3: HAND CLOSED - Confronto Inter-Trial sul canale migliore ---
    subplot(2, 2, 3); hold on;
    if ~any(isnan(MUAP_h_T1(:))), plot(t_axis, MUAP_h_T1(best_ch, :), 'Color', [0.2 0.7 0.3], 'LineWidth', 2); end
    if ~any(isnan(MUAP_h_T2(:))), plot(t_axis, MUAP_h_T2(best_ch, :), 'Color', [0.8 0.2 0.6], 'LineWidth', 1.5, 'LineStyle', '--'); end
    grid on; title(sprintf('HAND CLOSED: Allineamento Trial (Ch Best %d, R2D = %.2f)', best_ch, r_H1_H2));
    xlabel('Tempo (ms)'); ylabel('Ampiezza (\muV)');
    legend({'Trial 1', 'Trial 2'}, 'Location', 'best');
    axis tight;
    
    % --- Pannello 4: HAND CLOSED - Sovrapposizione morfologica dei 10 canali top ---
    subplot(2, 2, 4); hold on;
    if ~any(isnan(MUAP_h_all(:)))
        for tc_idx = 1:numel(topChans)
            ch = topChans(tc_idx);
            plot(t_axis, MUAP_h_all(ch, :), 'Color', colors_top10(tc_idx, :), 'LineWidth', 1.2);
        end
    end
    grid on; title('HAND CLOSED: Coerenza Forme d''Onda (10 Canali Top Matched)');
    xlabel('Tempo (ms)'); ylabel('Ampiezza (\muV)');
    axis tight;
    
    % Determina lo stato provvisorio di stabilità per il titolo
    if mean_score >= R_threshold_mean, provStatus = "Stable"; else, provStatus = "Unstable"; end
    
    % Titolo Globale della Figura con Riepilogo Metriche
    sgtitle(sprintf('Grid %d | MU %d | Task Orig: %s -> Stato Provv: %s\nMedia Intra-MU R2D = %.3f | Global Cross-Task R2D = %.3f', ...
        g, mu, T.TaskClass(row), provStatus, mean_score, r_Global), 'FontSize', 12, 'FontWeight', 'bold', 'Interpreter', 'none');
    
    % Salvataggio del Plot Grafico univoco per ogni MU
    plotFileName = sprintf('%s/Grid%d_MU%02d_Diagnostic.png', plotFolder, g, mu);
    saveas(fig, plotFileName);
    close(fig);
    
    if mod(row, 10) == 0 || row == totalRows
        fprintf(' -> Elaborate e salvate %d/%d immagini...\n', row, totalRows);
    end
end

% Ripristiniamo la visibilità normale dei grafici
set(0, 'DefaultFigureVisible', 'on');

%% ========================================================================
% STABILITA' INTRA-MU (Filtraggio iniziale in Tabella)
%% ========================================================================
fprintf('\nFase 3: Filtraggio Stabilità (Scarto se Mean_All_Cases < %.2f)...\n', R_threshold_mean);
for row = 1:height(T)
    if isnan(T.Mean_All_Cases(row))
        T.FinalSet_New(row) = "Rejected_NoData";
        continue;
    end
    
    if T.Mean_All_Cases(row) >= R_threshold_mean
        T.KeepMU_New(row) = true;
        if T.TaskClass(row) == "pinch_only", T.FinalSet_New(row) = "Pinch_Only_Accepted";
        elseif T.TaskClass(row) == "hand_only", T.FinalSet_New(row) = "Hand_Only_Accepted";
        else, T.FinalSet_New(row) = "Shared_Accepted";
        end
    else
        T.FinalSet_New(row) = "Rejected_Unstable"; 
    end
end

%% ========================================================================
% 1B: CONFRONTO INTER-MU CON CORRELAZIONE MEDIA SUI TRIAL VALIDATI
%% ========================================================================
fprintf('\nFase 1B: Calcolo Cross-Correlazione Inter-MU basata sulla media dei trial...\n');
dupTable_All = table(); 
grids = fieldnames(MU_Collector);
for i = 1:numel(grids)
    g_str = grids{i}; g_idx = str2double(extractAfter(g_str, '_'));
    data = MU_Collector.(g_str); 
    if isempty(fieldnames(data)), continue; end
    nMU = size(data.P_T1, 3);
    
    for m1 = 1:nMU
        for m2 = m1+1:nMU
            v1 = data.P_All(:,:,m1); if any(isnan(v1(:))), v1 = data.H_All(:,:,m1); end
            if any(isnan(v1(:))), continue; end
            v1_ch = max(v1,[],2) - min(v1,[],2); [~, sCh] = sort(v1_ch,'descend'); tCh = sCh(1:min(topK_corr,numel(sCh)));
            
            r_P1 = compute_muap_xcorr2D(data.P_T1(:,:,m1), data.P_T1(:,:,m2), tCh);
            r_P2 = compute_muap_xcorr2D(data.P_T2(:,:,m1), data.P_T2(:,:,m2), tCh);
            r_H1 = compute_muap_xcorr2D(data.H_T1(:,:,m1), data.H_T1(:,:,m2), tCh);
            r_H2 = compute_muap_xcorr2D(data.H_T2(:,:,m1), data.H_T2(:,:,m2), tCh);
            
            trial_corrs = [r_P1, r_P2, r_H1, r_H2];
            r_media_inter = mean(trial_corrs, 'omitnan');
            
            if isnan(r_media_inter), continue; end
            
            if r_media_inter > Duplicate_threshold
                v1_amp = data.P_All(:,:,m1); if any(isnan(v1_amp(:))), v1_amp = data.H_All(:,:,m1); end
                v2_amp = data.P_All(:,:,m2); if any(isnan(v2_amp(:))), v2_amp = data.H_All(:,:,m2); end
                amp1 = max(v1_amp(:)) - min(v1_amp(:));
                amp2 = max(v2_amp(:)) - min(v2_amp(:));
                
                newRow = table({g_str}, m1, m2, r_P1, r_P2, r_H1, r_H2, r_media_inter, amp1, amp2, ...
                    'VariableNames', {'Grid', 'MU1', 'MU2', 'r_P1', 'r_P2', 'r_H1', 'r_H2', 'InterMU_Corr', 'Amp_MU1', 'Amp_MU2'});
                dupTable_All = [dupTable_All; newRow];
            end
        end
    end
end

% --- TABELLA 1: INTRA-MU ---
disp('--- TABELLA 1: PANORAMICA CON COMBINAZIONI INTRA-MU SPLITTATE ---');
Tab_View = T(:, {'Grid', 'MU', 'TaskClass', 'R2D_Pinch', 'R2D_Hand', ...
                 'R2D_P1_H2', 'R2D_P2_H1', 'R2D_P1_H1', 'R2D_P2_H2', ...
                 'R2D_Global_Pinch_Hand', 'Mean_All_Cases', 'FinalSet_New'});
vars_to_round1 = {'R2D_Pinch', 'R2D_Hand', 'R2D_P1_H2', 'R2D_P2_H1', 'R2D_P1_H1', 'R2D_P2_H2', 'R2D_Global_Pinch_Hand', 'Mean_All_Cases'};
for v = 1:numel(vars_to_round1)
    Tab_View.(vars_to_round1{v}) = round(Tab_View.(vars_to_round1{v}), 3);
end
disp(Tab_View(1:min(15, height(Tab_View)), :));

% --- TABELLA 2A: INTER-MU NON FILTRATA ---
fprintf('\n--- TABELLA 2A: DUPLICATI SU TUTTE LE UNITA'' (Unfiltered, Soglia Media > %.2f) ---\n', Duplicate_threshold);
if ~isempty(dupTable_All)
    dupTable_All_Print = dupTable_All;
    vars_to_round2 = {'r_P1', 'r_P2', 'r_H1', 'r_H2', 'InterMU_Corr'};
    for v = 1:numel(vars_to_round2)
        dupTable_All_Print.(vars_to_round2{v}) = round(dupTable_All_Print.(vars_to_round2{v}), 3);
    end
    disp(dupTable_All_Print(1:min(20, height(dupTable_All_Print)), :));
else
    disp('Nessun duplicato rilevato in assoluto.');
end

% --- TABELLA 2B: INTER-MU FILTRATA (Solo unità stabili) ---
fprintf('\n--- TABELLA 2B: DUPLICATI SOLO TRA UNITA'' APPROVATE DALL''INTRA-MU (Filtered, Soglia Media > %.2f) ---\n', Duplicate_threshold);
dupTable_Filtered = table();
if ~isempty(dupTable_All)
    for k = 1:height(dupTable_All)
        g_idx = str2double(extractAfter(dupTable_All.Grid{k}, '_'));
        idx1 = find(T.Grid == g_idx & T.MU == dupTable_All.MU1(k));
        idx2 = find(T.Grid == g_idx & T.MU == dupTable_All.MU2(k));
        
        if ~isempty(idx1) && ~isempty(idx2)
            if contains(T.FinalSet_New(idx1), "Accepted") && contains(T.FinalSet_New(idx2), "Accepted")
                dupTable_Filtered = [dupTable_Filtered; dupTable_All(k, :)];
            end
        end
    end
end
if ~isempty(dupTable_Filtered)
    dupTable_Filtered_Print = dupTable_Filtered;
    vars_to_round3 = {'r_P1', 'r_P2', 'r_H1', 'r_H2', 'InterMU_Corr'};
    for v = 1:numel(vars_to_round3)
        dupTable_Filtered_Print.(vars_to_round3{v}) = round(dupTable_Filtered_Print.(vars_to_round3{v}), 3);
    end
    disp(dupTable_Filtered_Print);
else
    disp('Nessun duplicato rilevato tra le sole unità stabili.');
end

%% ========================================================================
% 4: SECONDO FILTRO (Rimozione Duplicati basata sulla Tabella 2B)
%% ========================================================================
fprintf('\nFase 4: Rimozione Duplicati basata sulle unità stabili...\n');
scartati_count = 0;
if ~isempty(dupTable_Filtered)
    for k = 1:height(dupTable_Filtered)
        g_idx = str2double(extractAfter(dupTable_Filtered.Grid{k}, '_'));
        mu1 = dupTable_Filtered.MU1(k);
        mu2 = dupTable_Filtered.MU2(k);
        
        idx1 = find(T.Grid == g_idx & T.MU == mu1);
        idx2 = find(T.Grid == g_idx & T.MU == mu2);
        
        if contains(T.FinalSet_New(idx1), "Accepted") && contains(T.FinalSet_New(idx2), "Accepted")
            if dupTable_Filtered.Amp_MU1(k) < dupTable_Filtered.Amp_MU2(k)
                T.FinalSet_New(idx1) = "Rejected_Duplicate"; T.KeepMU_New(idx1) = false;
            else
                T.FinalSet_New(idx2) = "Rejected_Duplicate"; T.KeepMU_New(idx2) = false;
            end
            scartati_count = scartati_count + 1;
        end
    end
end
fprintf('Rimossi %d duplicati effettivi dalle unità stabili.\n', scartati_count);
disp('--- TABELLA 3: CONTEGGIO STATO FINALE PER CATEGORIA DOPO SCREMATURA ---');
disp(groupsummary(T, {'TaskClass','FinalSet_New'}));

% Salvataggio dati finale
save(fullfile(dataFolder, 'results_R2D.mat'), 'T', 'fs', 'MU_Index_Map');
writetable(T, fullfile(dataFolder, 'table_R2D.csv'));
shared_accepted = T(T.KeepMU_New == true, :);
save('filt_indices_all.mat', 'shared_accepted');
fprintf('\n[INFO] Salvate %d unità finali in filt_indices_all.mat.\n', height(shared_accepted));

set(0, 'Format', origFormat); % Ripristina il formato originale

%% ========================================================================
% FUNZIONI LOCALI
%% ========================================================================
function MUAP = compute_sta(EMG, spikes, pre, post)
    L = pre + post + 1; MUAP = nan(size(EMG,1), L);
    if numel(spikes) < 3, return; end
    spikes = spikes(spikes > pre & spikes <= size(EMG,2)-post);
    if isempty(spikes), return; end
    for ch = 1:size(EMG,1)
        snippets = zeros(numel(spikes), L);
        for k = 1:numel(spikes), snippets(k,:) = EMG(ch, spikes(k)-pre : spikes(k)+post); end
        MUAP(ch,:) = mean(snippets, 1);
    end
end

% Calcolo Cross-Correlazione 2D normalizzata
function R2D = compute_muap_xcorr2D(A, B, chList)
    if any(isnan(A(:))) || any(isnan(B(:))), R2D = NaN; return; end
    A = A(chList, :); B = B(chList, :);
    A = A - mean(A(:)); B = B - mean(B(:));
    if norm(A(:)) == 0 || norm(B(:)) == 0, R2D = NaN; return; end
    A = A / norm(A(:)); B = B / norm(B(:));
    XC = normxcorr2(A, B); R2D = max(XC(:));
end