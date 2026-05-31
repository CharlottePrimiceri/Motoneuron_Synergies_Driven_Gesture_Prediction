# Motoneuron_Synergies_Driven_Gesture_Prediction

## Motor Unit Decomposition Strategy on the HD-FW KIN PhysioNet Dataset

The current decomposition work is focused on the HD-FW KIN PhysioNet dataset, which provides synchronized high-density sEMG and hand kinematics. The full dataset contains 448 HD-sEMG channels sampled at 2000 Hz: 256 wrist channels and 192 forearm channels. In this project, the decomposition target is currently restricted to the 192 forearm channels, corresponding to three 8 x 8 grids of 64 channels each.

The objective is to extract motor unit spike trains from the forearm HD-sEMG and later use them to compute smoothed discharge rates and motoneuron synergies.

