# Netlogo-pong
Simple netlogo implementation of a learning agent playing pong.

You can read a survey on "Learning Agents for Pong" [here](https://github.com/davidepietrasanta/Netlogo-pong/blob/main/Learning_Agents_for_Pong__A_Survey.pdf).

<kbd>
<img src="https://github.com/davidepietrasanta/Netlogo-pong/blob/main/survey/images/Netlogo.png" alt="drawing" width="600"/>
</kbd>

## Folders

```text

├── pong_exp                                # Experiments folder
│   ├─ rnd_prob_0.1                         # Experiment with probability 0.1
│   ├─ rnd_prob_0.3                         # Experiment with probability 0.3
│   └─ rnd_prob_0.5                         # Experiment with probability 0.5
├── survey                                  # LaTeX survey
|── Learning_Agents_for_Pong__A_Survey.pdf  # PDF survey
|── quality.csv                             # A quality matrix
└── pong.nlogo                              # Actual code
```

# Play

If you want to see how an agent plays pong against a Scripted AI just do `SETUP`, `LOAD` (optional) and then `PLAY`.

This way the agent is not learning but simply playing the best action based on the quality matrix (quality.csv).

If you don't press `LOAD` the agent operates with an empty quality matrix (zeros only).

In the `pong_exp` folder you can find quality matrices (quality_20k_episodes_rnd-prob-0.1.csv, etc.). By renaming them to `quality.csv` and putting them in the directory where the netlogo code is (pong.nlogo) you can see how the agent plays.

# Q-Learning

You can generate your own quality matrix by doing `SETUP`, `LOAD` (optional) and then `Q-LEARNING`.

This way the agent is learning and generating a quality matrix (quality.csv).

If you don't press `LOAD` the learning starts with an empty quality matrix (zeros only).

# SARSA

You can generate your own quality matrix by doing `SETUP`, `LOAD` (optional) and then `SARSA`.

This way the agent is learning and generating a quality matrix (quality.csv).

If you don't press `LOAD` the learning starts with an empty quality matrix (zeros only).
