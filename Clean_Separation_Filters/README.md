# HD-sEMG Signal Processing and Synergy Extraction Pipeline

The current decomposition work is focused on the HD-FW KIN PhysioNet dataset, which provides synchronized high-density sEMG and hand kinematics. The full dataset contains 448 HD-sEMG channels sampled at 2000 Hz: 256 wrist channels and 192 forearm channels. In this project, the decomposition target is currently restricted to the 192 forearm channels, corresponding to three 8 x 8 grids of 64 channels each.

The objective is to extract motor unit spike trains from the forearm HD-sEMG and later use them to compute smoothed discharge rates and motoneuron synergies for its subsequent use in hand kinematics prediction.

The pipeline consists of:

**Raw HD-sEMG + glove recordings → kinematic segmentation → HD-sEMG preprocessing → MU decomposition → motor unit validation and cleaning → cross-trial motor unit tracking → smoothed discharge rates → NNMF synergy extraction**

---

# 1. Glove Data Processing and Isometric Segmentation

**Language:** Python

The first stage processes the 14-channel 5DT Data Glove recordings and identifies the stable portions of each gesture corresponding to the isometric phases of the experimental protocol.

### Processing steps

- Raw glove recordings are loaded from the acquisition files.
- The 14 sensor channels are normalized to a common range.
- Joint angular velocity is computed from the glove signals.
- Samples below a subject-specific angular velocity threshold are considered stable.
- The threshold is selected for each participant based on the observed execution dynamics, typically within a range of approximately **200–400 °/s**.
- Continuous stable intervals of at least **3 seconds** are identified.
- These intervals are used to isolate the isometric contraction phases corresponding to the experimental tasks.

The segmentation is performed independently for each subject because the execution dynamics and the magnitude of the angular velocity can differ across participants.

The resulting time windows define the portions of the recordings used for subsequent HD-sEMG processing.

---

# 2. HD-sEMG Preprocessing and Synchronization

**Language:** Python

The HD-sEMG acquisition consists of three independent forearm electrode grids, each containing 64 channels, for a total of **192 channels**.

Only the three forearm grids are used for the motor unit analysis.

### Processing steps

- The 192 HD-sEMG channels are extracted from the original acquisition.
- The physical organization of the three independent **8 × 8 electrode grids** is preserved.
- The HD-sEMG recordings are temporally aligned with the glove recordings.
- The portions corresponding to the previously detected isometric windows are extracted.
- The signals are filtered using a **fourth-order zero-phase Butterworth band-pass filter** with cutoff frequencies of **20 Hz and 500 Hz**.
- The preprocessed signals are temporally upsampled from **2000 Hz to 4000 Hz** before motor unit decomposition.

The initial filtering is performed before concatenation to remove low-frequency movement artifacts and high-frequency noise while preserving the frequency range relevant for motor unit action potentials.

The temporal upsampling increases the temporal resolution available to the decomposition procedure.

---

# 3. MUedit Data Formatting

**Language:** MATLAB

The preprocessed HD-sEMG signals are converted into the MATLAB data structure required by the MUedit decomposition framework.

---

# 4. Multi-Trial / Multi-Task Motor Unit Decomposition

**Language:** MATLAB

Motor unit decomposition is performed on concatenated isometric contractions.

The concatenation strategy is used to increase the amount of available motor unit discharge activity while maintaining the same subject and electrode configuration.

For the multi-task analysis, precision pinch and hand close contractions can be concatenated to investigate whether motor units can be consistently identified across different motor tasks.

Repeated contractions of the same task can also be included to increase the number of available discharge events and assess decomposition repeatability.

### Decomposition

The decomposition is performed independently for each 64-channel electrode grid using the MUedit framework.

A spatio-temporal extension factor of **4** is applied before decomposition.

The resulting separation parameters are retained for subsequent cross-trial projection:

- Whitening matrix `E`
- Whitening/decomposition matrix `D`
- Motor unit separation filters `MUFilters`

These parameters define the projection used to identify the same motor units in subsequent recordings acquired with the same electrode configuration.

---

# 5. Motor Unit Quality Control and Cleaning

**Language:** MATLAB

The initial decomposition produces candidate motor units that require additional quality control before being used for synergy extraction.

The cleaning stage includes both discharge-based filtering and MUAP-based validation.

### Minimum discharge criterion

Motor units producing fewer than **15 discharge events within a 5-second segment** are discarded.

This removes units with insufficient activity for reliable characterization and subsequent analysis.

### MUAP estimation

For each candidate motor unit, a **Spike-Triggered Average (STA)** is computed to estimate its spatio-temporal Motor Unit Action Potential (MUAP) waveform.

The MUAP provides a spatial and temporal signature of the motor unit across the electrode grid.

### MUAP similarity and duplicate detection

The estimated MUAPs are compared using normalized two-dimensional cross-correlation.

Highly similar MUAPs may correspond to duplicate detections of the same physiological motor unit.

When duplicate units are identified, the candidate with the lower signal amplitude is removed.

The final set of motor units is therefore obtained after combining discharge-based filtering with MUAP-based validation.

---

# 6. Cross-Trial Motor Unit Tracking

After obtaining a cleaned decomposition from a reference recording, the corresponding separation parameters are applied to other trials.

This procedure avoids independently decomposing every trial and allows the activity of previously identified motor units to be tracked across recordings.

The saved decomposition parameters:

```text
E
D
MUFilters
```

are applied to the corresponding upsampled HD-sEMG recordings.

The resulting candidate discharge events are then evaluated to distinguish genuine motor unit activity from noise and cross-talk.

A clustering procedure based on **K-means** is used during candidate spike classification.

The objective is to obtain consistent motor unit spike trains across repeated trials and different task conditions.

---

# 7. Motor Unit Discharge Rate Estimation

The identified motor unit spike trains are converted into continuous activation signals.

Each binary discharge train is filtered using a **2.5 Hz Butterworth low-pass filter** to obtain a smoothed discharge-rate representation.

Negative values introduced by filtering are removed.

For each motor unit, the resulting signal is normalized to a common range.

The normalized Smoothed Discharge Rates (SDRs) are then concatenated across the analyzed motor units and recording segments to form the global neural activity matrix where the rows represent motor units and the columns represent temporal samples.

This matrix provides the input representation for the subsequent neural synergy analysis.

---

# 8. Neural Synergy Extraction using NNMF

Non-Negative Matrix Factorization (NNMF) is applied to the normalized SDR matrix.

The temporal activations contained in \(H\) are subsequently used as the low-dimensional neural representation for the deep-learning-based hand pose prediction.

---

# 9. Synergy Representation Across Subjects

For the multi-subject analysis, a fixed number of **two neural synergies** is used to construct a common latent representation across participants.

Although the reconstruction accuracy can generally increase when a larger number of synergies is extracted, fixing the dimensionality to two simplifies the construction of a unified dataset and ensures that the neural input provided to the deep learning model has the same dimensionality for every participant.

The ordering of the extracted synergies is manually aligned across subjects to maintain a consistent interpretation:

- **Synergy 1:** predominantly associated with the precision pinch task, or shared across tasks when applicable.
- **Synergy 2:** predominantly associated with the hand close task.

An additional dataset can also be constructed using a subject-specific number of synergies, selected according to the modal number of synergies identified from the NMF reconstruction analysis.

This alternative representation is used to investigate whether allowing the latent dimensionality to vary according to the individual decomposition provides advantages over the fixed two-synergy representation.

---

# 10. Output of the Pipeline

The final output of the processing pipeline consists of:

1. Cleaned motor unit spike trains.
2. Cross-trial motor unit activity.
3. Smoothed and normalized motor unit discharge rates.
4. Neural synergy weights \(W\).
5. Neural synergy activations \(H\).

The temporal matrix \(H\) represents the final low-dimensional neural signal used for the subsequent hand-pose prediction experiments.

The overall processing chain can therefore be summarized as:

```text
Raw HD-sEMG
      │
      ▼
Filtering and synchronization
      │
      ▼
Isometric segmentation
      │
      ▼
Temporal upsampling
      │
      ▼
MUedit formatting
      │
      ▼
Motor unit decomposition
      │
      ▼
MU quality control
      │
      ▼
MUAP validation / duplicate removal
      │
      ▼
Cross-trial filter projection
      │
      ▼
Motor unit spike trains
      │
      ▼
Smoothed Discharge Rates
      │
      ▼
NNMF
      │
      ├── W: Synergy weights
      │
      └── H: Synergy activations
                  │
                  ▼
          Hand pose prediction
```
