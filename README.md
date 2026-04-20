# Motoneuron_Synergies_Driven_Gesture_Prediction

## Hand Visualization in Unity from 5DT Glove Signals

- `Glove_analysis.ipynb`: notebook used to inspect the glove signals, read the WFDB record, check channel names, verify signal shape and duration, and converted into a CSV suitable for Unity. The signal matrix has shape:
  - `37400 x 14`
  which corresponds to 14 glove channels sampled over approximately 187 seconds with `fs = 200 Hz`. These channels are not assumed to be directly expressed in anatomical degrees. In practice, they behave as glove sensor outputs that vary consistently with finger posture. For visualization, they are therefore converted into normalized or scaled angles suitable for the Unity rig. For Unity playback, the preferred file is the CSV converted for rendering, `glove_unity_deg.csv` with columns:

  - `time_s`, `Thumb_MCP`, `Thumb_IP`, `Thumb_Index_abd`, `Index_MCP`, `Index_PIP`, `Index_Middle_abd`, `Middle_MCP`, `Middle_PIP`, `Middle_Ring_abd`, `Ring_MCP`, `Ring_PIP`, `Ring_Little_abd`, `Little_MCP`, `Little_PIP`.

- `HandFingers.cs`: Unity C# script used to read a CSV file and animate the rigged hand in Unity.
  
- `glove_sample_subj_01_trial_01/`: sample folder containing the glove record in WFDB format (`.hea` and `.dat`) and the CSV for Unity.
  
### Unity setup

A rigged hand model must be imported into Unity. The right hand model used for visualization was obtained from the Unity XR package, and the project was developed using Unity Editor version 6000.4.3f1. The important requirement is that the hand contains separate finger bones such as:

- `b_r_thumb1`, `b_r_thumb2`
- `b_r_index1`, `b_r_index2`, `b_r_index3`
- `b_r_middle1`, `b_r_middle2`, `b_r_middle3`
- `b_r_ring1`, `b_r_ring2`, `b_r_ring3`
- `b_r_little1`, `b_r_little2`, `b_r_little3`

Attach `HandFingers.cs` to the root object of the hand.
The script should then expose, in the Unity Inspector:

- a `TextAsset` field for the CSV file,
- `Transform` references for the thumb, index, middle, ring and little finger bones,
- optional scale and inversion parameters for flexion and abduction.
In the Inspector, assign:

- the exported glove CSV file,
- the correct bone transforms for all fingers.

For example:

- `index1 -> b_r_index1`
- `index2 -> b_r_index2`
- `index3 -> b_r_index3`

For now, the Unity script replays the glove motion offline.

1. load all CSV rows at startup,
2. store the initial local rotations of the bones,
3. advance one sample at a time according to the chosen sample rate,
4. apply finger flexion and abduction to the corresponding bones,
5. loop the sequence when the end of the trial is reached.

### Practical assumptions used during playback

- Flexion is applied to the finger joints as a rotation around the local flexion axis of the bone.
- For the tested rig, flexion was found empirically by rotating bones manually in the Inspector.
- Distal interphalangeal joints (DIP) can be approximated from the PIP angle, for example using a factor such as `0.6 * PIP`.
- Abduction is applied only to the base finger bones to avoid unrealistic twisting of the whole finger chain.
- Sign inversions are sometimes necessary because the rig coordinate system may use the opposite rotation direction compared to the glove convention.

### Recording the hand motion

To capture a video from Unity:

1. install the Recorder package from the Package Manager,
2. create a dedicated camera close to the hand,
3. use `Targeted Camera` as the Recorder source,
4. choose manual recording or a sufficiently long recording interval,
5. export the video in a standard format such as MP4.

A video of the sample data can be found in the following drive:

https://drive.google.com/file/d/1xKhL-a1pIBRN3dIU34b6PNTa2PQMBCOn/view?usp=sharing
