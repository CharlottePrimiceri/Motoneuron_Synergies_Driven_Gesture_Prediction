# Motoneuron_Synergies_Driven_Gesture_Prediction

## Hand Visualization in Unity from 5DT Glove Signals

- `Glove_analysis.ipynb`: notebook used to inspect the glove signals, read the WFDB record, check channel names, verify signal shape and duration, and converted into a CSV suitable for Unity. The signal matrix has shape:
  - `37400 x 14`
  which corresponds to 14 glove channels sampled over approximately 187 seconds with `fs = 200 Hz`. For Unity playback, the preferred file is the CSV already converted for rendering, `glove_unity_deg.csv` with columns such as:

  - `time_s`
  - `Thumb_MCP`
  - `Thumb_IP`
  - `Thumb_Index_abd`
  - `Index_MCP`
  - `Index_PIP`
  - `Index_Middle_abd`
  - `Middle_MCP`
  - `Middle_PIP`
  - `Middle_Ring_abd`
  - `Ring_MCP`
  - `Ring_PIP`
  - `Ring_Little_abd`
  - `Little_MCP`
  - `Little_PIP`

- `HandFingers.cs`: Unity C# script used to read a CSV file and animate the rigged hand in Unity.
- `glove_sample_subj_01_trial_01/`: sample folder containing the glove record in WFDB format (`.hea` and `.dat`) and the CSV for Unity. 
