# Hand Pose Prediction Driven by Motoneuron Synergies

This repository contains the processing and learning pipeline developed for my thesis **"Hand Pose Prediction Driven by Motoneuron Synergies"**.

The project investigates how to build a pipeline for predicting hand kinematics from neural activation patterns extracted from high-density surface electromyography (HD-sEMG) exploiting motoneuron synergies as in "Merging motoneuron and postural synergies in prosthetic hand design for natural bionic interfacing" by Capsi-Morales et al. .

The thesis investigates whether the relationship can be learned from synchronized examples of neural activity and hand kinematics through an **LSTM (Long Short-Term Memory)** network.

The repository is organized into three main components:

- **`preprocessing/`**: HD-sEMG processing, motor unit decomposition, motor unit validation and tracking, discharge rate estimation, and neural synergy extraction.
- **`LSTM/`**: learning of the mapping between temporal synergy activations and hand kinematics using an LSTM network, including the experimental analyses and model considerations.
- **`Unity_Viz/`**: offline visualization of the recorded or predicted hand motion using a rigged hand in Unity.

The pdf Presentation is also attached to visualize plots and resuls. 


## 1. Pipeline

The complete processing and learning pipeline can be summarized as:

```text
HD-sEMG + Hand Kinematics
          │
          ▼
┌─────────────────────────────┐
│        Preprocessing        │
│                             │
│  • HD-sEMG filtering        │
│  • Synchronization          │
│  • Isometric segmentation   │
│  • MUedit data formatting   │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│ Motor Unit Decomposition    │
│                             │
│  • Multi-task decomposition │
│  • MU validation            │
│  • MUAP analysis            │
│  • Cross-trial tracking     │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│   Neural Synergy Extraction │
│                             │
│  Motor-unit discharge rates │
│             ↓               │
│            NNMF             │
│             ↓               │
│      W and H matrices       │
└──────────────┬──────────────┘
               │
               │ temporal synergy activations H(t)
               ▼
┌─────────────────────────────┐
│          LSTM               │
│                             │
│  Neural synergies →         │
│  hand kinematics            │
└──────────────┬──────────────┘
               │
               │ predicted hand pose
               ▼
┌─────────────────────────────┐
│      Unity Visualization    │
│                             │
│  Predicted / recorded hand  │
│  motion rendered on a       │
│  rigged 3D hand             │
└─────────────────────────────┘
```

The first part of the pipeline converts the raw HD-sEMG recordings into a lower dimensional neural representation. The second part uses this representation as the input to a recurrent neural network.



## 2. Preprocessing and Neural Synergy Extraction

The `preprocessing/` folder contains the complete signal-processing pipeline required to obtain neural synergies from the HD-sEMG recordings.

The processing includes:

- glove signal inspection and kinematic segmentation;
- HD-sEMG preprocessing and synchronization;
- formatting of the recordings for MUedit;
- multi-trial / multi-task motor-unit decomposition;
- motor-unit quality control and cleaning;
- motor-unit action-potential validation;
- cross-trial motor-unit tracking and filter projection;
- smoothed motor-unit discharge-rate estimation;
- neural synergy extraction using NNMF.

The output of this stage is a temporal representation of the neural synergies used as the neural input representation.


## 3. Learning Hand Pose from Neural Synergies

The `LSTM/` folder contains the training to learn the relationship between the extracted neural synergies and the corresponding hand configuration measured by the glove.

The experiments investigate progressively:

- learning within the same participant;
- prediction on unseen trials;
- prediction for an unseen participant;
- training using multiple participants;
- extension from a single motor task to multiple hand tasks.


## 4. Hand Visualization in Unity

The `Unity_Viz/` folder contains the visualization component of the project.


## 5. Repository Structure

```text
.
├── README.md
│
├── preprocessing/
│   ├── README.md
│   ├── python/
│   └── matlab/
│
├── LSTM/
│   ├── README.md
│   └── *.ipynb
│
└── Unity_Visualization/
    ├── README.md
    └── HandFingers.cs

```

## 6. Acknowledgements

This work was developed as part of my Master's thesis in Artificial Intelligence and Robotics at **Sapienza University of Rome**, under the supervision of **Prof. Marilena Vendittelli** and the co-supervision of **Dr. Emma Colamarino**, **Prof. Jlenia Toppi**, **Dr. Emanuele De Santis**.

## Bibliography

@article{PhysioNet-hand-kinematics-semg-1.0.0,
  author = {Zhao, Zeming and Guo, Weichao and Zhou, Zeyu},
  title = {{A database of hand kinematics, high-density sEMG of forearm and wrist for motion intent recognition}},
  journal = {{PhysioNet}},
  year = {2025},
  month = jan,
  note = {Version 1.0.0},

Avrillon, S., Hug, F., Baker, S.N., Gibbs, C., and Farina, D. (2024). Tutorial on MUedit: An open-source software for identifying and analysing the discharge timing of motor units from electromyographic signals. J Electromyogr Kinesiol 77, 102886. 10.1016/j.jelekin.2024.102886,
  doi = {10.13026/ch3e-c195},
  url = {https://doi.org/10.13026/ch3e-c195}
},

@article{capsi2025merging,
  title={Merging motoneuron and postural synergies in prosthetic hand design for natural bionic interfacing},
  author={Capsi-Morales, Patricia and Barsakcioglu, Deren Y and Catalano, Manuel G and Grioli, Giorgio and Bicchi, Antonio and Farina, Dario},
  journal={Science Robotics},
  volume={10},
  number={98},
  pages={eado9509},
  year={2025},
  publisher={American Association for the Advancement of Science}
}
