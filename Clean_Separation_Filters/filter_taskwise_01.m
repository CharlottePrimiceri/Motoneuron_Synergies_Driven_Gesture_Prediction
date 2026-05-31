%% 01_filter_and_classify_taskwise.m
% Pipeline Unificata: Filtraggio Ordinato, Classificazione Cross-Task e Diagnostica MUedit
%
% Logica di filtraggio:
%   1) Verifica FR media della task <= 40 Hz.
%   2) Verifica presenza di >= 15 spike in almeno uno dei due trial (T1 OR T2).
%   3) Esclusione immediata delle MU non valide.
%   4) Generazione dei report diagnostici completi e liste ID per MUedit.
%   5) Classificazione cross-task a 3 classi pure (pinch_only, hand_only, shared).

clear; clc;

%% ========================================================================
% 1. CONFIGURAZIONE INPUT E PARAMETRI
%% ========================================================================

infile = "C:\Users\Charlie XD\Documents\AAAUNIVERSITAAAAAAAAAAAA'\Tesi\Motoneuron_Synergies_Driven_Gesture_Prediction\data_conc_subj1_trial_1_10_13\signal_mov10_mov13_trial1_trial2_filt_for_muedit.mat_decomp";
load(infile, 'signal', 'parameters');

fs = signal.fsamp;
nGrid = numel(signal.Pulsetrain);

% --- Criteri di Selezione ---
minSpikesTrial = 15;  % Soglia minima di spike in almeno un trial
minFR = 0;            % Frequenza di scarica minima ammessa (Hz)
maxFR = 40;           % Frequenza di scarica massima ammessa (Hz) - IL TUO SBARRAMENTO
maxInstFR = 40;       % Soglia per la rimozione di spike anomali (Hz)
maxCoV_ISI = 2.0;     % Valore di backup per CoV

%% ========================================================================
% 2. DEFINIZIONE DEI SEGMENTI TEMPORALI (TRIAL)
%% ========================================================================

mov10_trial1 = [1 9999];
mov10_trial2 = [10000 20599];
mov13_trial1 = [20600 30879];
mov13_trial2 = [30880 40719];

tasks(1).name = 'pinch';
tasks(1).segments = [mov10_trial1; mov10_trial2];

tasks(2).name = 'hand_closed';
tasks(2).segments = [mov13_trial1; mov13_trial2];

filtered = struct();
summaryRows = {};

%% ========================================================================
% 3. CORE LOOP 1: FILTRAGGIO TASK-WISE
%% ========================================================================

for g = 1:nGrid
    if isempty(signal.Pulsetrain{g}), continue; end
    muCount = size(signal.Pulsetrain{g}, 1);
    keep_any = false(muCount, 1);

    for t = 1:numel(tasks)
        taskName = tasks(t).name;
        segs = tasks(t).segments;

        keep_task = false(muCount, 1);
        clean_discharges_task = cell(1, muCount);

        for mu = 1:muCount
            spk_original = sort(signal.Dischargetimes{g, mu}(:));
            allCleanSpikes = [];

            segNSpikes = nan(size(segs,1), 1);
            segFR = nan(size(segs,1), 1);
            segRemoved = zeros(size(segs,1), 1);
            segResults = strings(size(segs,1), 1);

            % Estrazione e pulizia spike per i singoli trial
            for s = 1:size(segs, 1)
                segStart = segs(s, 1); segEnd = segs(s, 2);
                segDuration = (segEnd - segStart + 1) / fs;

                spkSeg = spk_original(spk_original >= segStart & spk_original <= segEnd);
                spkSeg = sort(spkSeg(:));

                [spkSegClean, nRemoved] = remove_fast_spikes(spkSeg, fs, maxInstFR);
                nSpikesSeg = numel(spkSegClean);
                frSeg = nSpikesSeg / segDuration;

                if nSpikesSeg >= minSpikesTrial
                    segResults(s) = sprintf("active_N%d", nSpikesSeg);
                else
                    segResults(s) = "low_activity";
                end

                segNSpikes(s) = nSpikesSeg; segFR(s) = frSeg; segRemoved(s) = nRemoved;
                allCleanSpikes = [allCleanSpikes; spkSegClean(:)]; 
            end

            allCleanSpikes = sort(allCleanSpikes);
            nSpikesTask = numel(allCleanSpikes);
            
            taskDuration = 0;
            for s = 1:size(segs, 1), taskDuration = taskDuration + (segs(s,2) - segs(s,1) + 1) / fs; end
            frTask = nSpikesTask / taskDuration;

            % Calcolo Coefficiente di Variazione dell'ISI (dimensione-libera)
            if nSpikesTask >= 3
                isi_seconds = diff(allCleanSpikes) / fs;
                covIsiTask = std(isi_seconds) / mean(isi_seconds);
            else
                covIsiTask = NaN;
            end

            % Conteggio segmenti attivi (quanti trial hanno almeno 15 spike)
            activeSegmentsCount = sum(segNSpikes >= minSpikesTrial);

            % --- APPLICAZIONE FILTRI NEUROFISIOLOGICI SEQUENZIALI ---
            reasonsTask = strings(0);
            
            % 1. Controllo Firing Rate della task (Deve essere <= 40 Hz)
            if frTask > maxFR
                reasonsTask(end+1) = "FR_too_high";
            end
            if frTask < minFR
                reasonsTask(end+1) = "FR_too_low";
            end
            
            % 2. Controllo presenza spike (Almeno 15 spike in T1 OPPURE in T2)
            if activeSegmentsCount == 0
                reasonsTask(end+1) = "insufficient_spikes";
            end

            % Esito finale per la singola task
            keep_task(mu) = isempty(reasonsTask);
            clean_discharges_task{mu} = allCleanSpikes;

            if isempty(reasonsTask), taskReason = "kept"; else, taskReason = strjoin(reasonsTask, "+"); end

            % Popolamento riga per riga per la tabella summary originale
            summaryRows(end+1, :) = { ...
                g, mu, taskName, nSpikesTask, frTask, covIsiTask, ...
                segNSpikes(1), segNSpikes(2), min(segNSpikes), max(segNSpikes), ...
                mean(segFR, 'omitnan'), max(segFR), sum(segRemoved), activeSegmentsCount, ...
                strjoin(segResults, " | "), taskReason, keep_task(mu)}; %#ok<SAGROW>
        end

        filtered(g).(taskName).keep = keep_task;
        filtered(g).(taskName).clean_dischargetimes = clean_discharges_task;
        filtered(g).(taskName).Pulsetrain = signal.Pulsetrain{g}(keep_task, :);
        filtered(g).(taskName).Dischargetimes_clean = clean_discharges_task(keep_task);

        keep_any = keep_any | keep_task(:);
    end
    filtered(g).keep_any = keep_any;
    filtered(g).keep_any_idx = find(keep_any);
    filtered(g).Pulsetrain_any = signal.Pulsetrain{g}(keep_any, :);
end

%% ========================================================================
% 4. SAVE & LE TUE STAMPE DIAGNOSTICHE ORIGINALI
%% ========================================================================

summary = cell2table(summaryRows, 'VariableNames', { ...
    'Grid', 'MU', 'Task', 'NSpikes_clean_task', 'FR_task_Hz', 'CoV_ISI_task', ...
    'NSpikes_trial1', 'NSpikes_trial2', 'MinSpikesTrial', 'MaxSpikesTrial', ...
    'MeanFR_trials_Hz', 'MaxTrialFR_Hz', 'RemovedFastSpikes', 'ActiveSegments', ...
    'SegmentActivity', 'TaskReason', 'Keep'});

save('01_decomp_filtered_taskwise.mat', 'signal', 'parameters', 'filtered', 'summary', ...
     'tasks', 'fs', 'minFR', 'maxFR', 'minSpikesTrial', 'maxCoV_ISI', 'maxInstFR', '-v7.3');
writetable(summary, '01_decomp_filtered_taskwise_fullfile.csv');

fprintf('\n=== KEPT MU PER GRID AND TASK ===\n');
for g = 1:max(summary.Grid)
    for t = unique(string(summary.Task))'
        idx = summary.Grid == g & string(summary.Task) == t;
        fprintf('Grid %d - %s: %d / %d MU kept\n', g, t, sum(summary.Keep(idx)), sum(idx));
    end
end

fprintf('\n=== ACTIVE IN ONE OR TWO TRIALS ===\n');
disp(groupsummary(summary(summary.Keep == true,:), ["Grid", "Task", "ActiveSegments"]));
disp('Salvati: 01_decomp_filtered_taskwise.mat / .csv');

% ========================================================================
% DIAGNOSTICA: REPORT RIMOZIONE SPIKE 
% ========================================================================
fprintf('\n=========================================================\n');
fprintf('        REPORT DIAGNOSTICO: RIMOZIONE SPIKE FAST\n');
fprintf('=========================================================\n');

idx_removed = summary.RemovedFastSpikes > 0;

if any(idx_removed)
    % Estraiamo solo le righe in cui il filtro ha effettivamente lavorato
    tbl_diagnostica = summary(idx_removed, {'Grid', 'MU', 'Task', 'NSpikes_clean_task', 'RemovedFastSpikes'});
    disp(tbl_diagnostica);
    
    total_removed = sum(summary.RemovedFastSpikes);
    total_spikes = sum(summary.NSpikes_clean_task) + total_removed;
    perc_removed = (total_removed / total_spikes) * 100;
    
    fprintf('-> Totale anomalie rimosse nel dataset: %d spike\n', total_removed);
    fprintf('-> Impatto sul dataset: %.3f%% degli spike totali eliminati.\n', perc_removed);
    fprintf('-> NOTA: Se l''impatto è basso (<1%%), il filtro agisce come "salvavita" isolato.\n');
else
    fprintf('Il filtro NON ha eliminato alcuno spike nell''intero dataset.\n');
    fprintf('Tutte le distanze tra spike consecutivi sono fisiologiche (> %d ms, cioè < %d Hz).\n', ...
        round(1000/maxInstFR), maxInstFR);
end
fprintf('=========================================================\n');

%% ========================================================================
% 5. ELENCO ID DELLE MU PER ISPEZIONE IN MUedit
%% ========================================================================

fprintf('\n=========================================================\n');
fprintf('        ELENCO ID DELLE MU SALVATE (RIFERIMENTO MUedit)\n');
fprintf('=========================================================\n');

grids = unique(summary.Grid);
tasks_list = unique(string(summary.Task))'; 

for g = grids'
    fprintf('\n GRIGLIA %d \n', g);
    for t = tasks_list
        idx_stable = (summary.Grid == g & string(summary.Task) == t & summary.Keep == true & summary.ActiveSegments == 2);
        mu_stable = summary.MU(idx_stable);
        
        idx_single = (summary.Grid == g & string(summary.Task) == t & summary.Keep == true & summary.ActiveSegments == 1);
        mu_single = summary.MU(idx_single);
        
        fprintf('  Movimento: %s\n', upper(t));
        fprintf('    ID MU Stabili (attive 2/2 trial) [%d unità]:\n      %s\n', numel(mu_stable), mat2str(mu_stable'));
        
        if ~isempty(mu_single)
            fprintf('    ID MU in un solo trial (attive 1/2) [%d unità]:\n      %s\n', numel(mu_single), mat2str(mu_single'));
        else
            fprintf('    ID MU in un solo trial (attive 1/2): Nessuna\n');
        end
        fprintf('  -------------------------------------------------------\n');
    end
end
fprintf('=========================================================\n');


%% ========================================================================
% 6. LOGICA DI CLASSIFICAZIONE CROSS-TASK A 3 CLASSI (PER PREPARARE LO SCRIPT 04)
%% ========================================================================

summary.Task = string(summary.Task);
pinchRows = summary(summary.Task == "pinch", :);
handRows  = summary(summary.Task == "hand_closed", :);

T = innerjoin( ...
    pinchRows(:, {'Grid','MU','NSpikes_clean_task','FR_task_Hz','Keep'}), ...
    handRows(:,  {'Grid','MU','NSpikes_clean_task','FR_task_Hz','Keep'}), ...
    'Keys', {'Grid','MU'}, ...
    'LeftVariables', {'Grid','MU','NSpikes_clean_task','FR_task_Hz','Keep'}, ...
    'RightVariables', {'NSpikes_clean_task','FR_task_Hz','Keep'} );

T.Properties.VariableNames = { ...
    'Grid', 'MU', ...
    'Pinch_Total', 'FR_pinch', 'KeepPinch', ...
    'Hand_Total',  'FR_hand',  'KeepHand'};

T.ValidPinch = T.KeepPinch == true;
T.ValidHand  = T.KeepHand  == true;

% Taglio istantaneo delle MU non attive o scartate in entrambi i compiti
T_clean = T(T.ValidPinch | T.ValidHand, :);

% Assegnazione pura delle 3 Macro-Classi Richieste (Senza logaritmo decisionale)
T_clean.TaskClass = strings(height(T_clean), 1);

for i = 1:height(T_clean)
    if T_clean.ValidPinch(i) && ~T_clean.ValidHand(i)
        T_clean.TaskClass(i) = "pinch_only";
        
    elseif ~T_clean.ValidPinch(i) && T_clean.ValidHand(i)
        T_clean.TaskClass(i) = "hand_only";
        
    elseif T_clean.ValidPinch(i) && T_clean.ValidHand(i)
        T_clean.TaskClass(i) = "shared";
    end
end

% Colonna di background necessaria per non mandare in crash lo script 04
T_clean.Log2_HandOverPinch = log2((T_clean.FR_hand + eps) ./ (T_clean.FR_pinch + eps));
taskPreferenceTable = T_clean;

% Salvataggio della tabella finale coerente per gli script successivi
writetable(taskPreferenceTable, '02_taskPreferenceTable.csv');
save('02_taskPreferenceTable.mat', 'taskPreferenceTable', 'signal', 'parameters', ...
     'filtered', 'summary', 'tasks', 'fs', '-v7.3');
fprintf('\n============================================================================\n');
fprintf('   CLASSIFICAZIONI MU SOPRAVVISUTE\n');
fprintf('============================================================================\n');

if ~isempty(taskPreferenceTable)
    % Estraiamo e mostriamo a schermo la tabella pulita ID per ID con la classe assegnata
    Mappe_Finali = taskPreferenceTable(:, {'Grid', 'MU', 'TaskClass', 'FR_pinch', 'FR_hand'});
    disp(Mappe_Finali);
    
    % Mostriamo anche un riepilogo numerico finale dei mazzetti per griglia
    fprintf('\n Conteggio totale dei gruppi per Griglia:\n');
    disp(groupsummary(taskPreferenceTable, ["Grid", "TaskClass"]));
else
    disp('ATTENZIONE: Nessuna MU ha superato i filtri combinati.');
end

%% ========================================================================
% FUNZIONI LOCALI
%% ========================================================================
function [spikesClean, nRemoved] = remove_fast_spikes(spikes, fs, maxInstFR)
    spikesClean = sort(spikes(:)); nRemoved = 0;
    if numel(spikesClean) < 2, return; end
    minISI_samples = round(fs / maxInstFR);
    changed = true;
    while changed
        changed = false;
        isi_samples = diff(spikesClean);
        badIdx = find(isi_samples < minISI_samples, 1, 'first');
        if ~isempty(badIdx)
            spikesClean(badIdx + 1) = [];
            nRemoved = nRemoved + 1; changed = true;
        end
    end
end