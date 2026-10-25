# Hand Pose Prediction

The input is the synergy activation matrix **H**, while the target consists of the **14 normalized raw glove sensor signals**.

## Data Preparation

The synergy activations and glove signals are synchronized at **200 Hz** using the segmentation information obtained during the preprocessing stage.

A **40-sample sliding window** is used, corresponding to a temporal context of **200 ms**.

The glove signals are used directly as normalized sensor values rather than being converted into joint angles, avoiding an additional transformation of the target data.

## LSTM Model

The temporal mapping is learned using a stacked LSTM consisting of:

- 2 LSTM layers;
- 64 hidden units;
- dropout = 0.3;
- fully connected layer with 32 units and ReLU;
- final linear layer with 14 outputs.

The model is trained for 50 epochs using the Adam optimizer with a learning rate of 0.001.

The training objective combines reconstruction accuracy and temporal smoothness.

## Experiments

The experiments were designed progressively to evaluate both learning and generalization:

1. **Single-task, Intra-Subject:** Hand Closed, using one synergy, with intra-subject evaluation.
2. **Two-task, Intra-Subject:** Precision Pinch followed by Hand Closed, using two synergies, with intra-subject evaluation.
3. **Two-task, Cross-subject:** training on Subject 2 and testing on the unseen Subject 3.
4. **Two-task, Cross-subject, Multi-subject Training:** training on Subjects 2, 7, 8 and 10, with Subject 3 kept exclusively for testing.

Subject 2 was selected for the initial experiments because its glove recordings showed comparatively high consistency across repeated trials.
In this folder the training for Two-task, Intra-Subject can be found. 
The results show that the LSTM can learn the temporal mapping between synergy activations and hand kinematics and can distinguish the two main motor phases in the concatenated task.
