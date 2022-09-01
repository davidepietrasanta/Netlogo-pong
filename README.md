# Netlogo-pong
Simple netlogo implementation of a learning agent playing pong.

You can read a survey on "Learning Agents for Pong" [here](https://github.com/davidepietrasanta/Netlogo-pong/blob/main/Learning_Agents_for_Pong__A_Survey.pdf).

<kbd>
<img src="https://github.com/davidepietrasanta/Netlogo-pong/blob/main/survey/images/Netlogo.png" alt="drawing" width="600"/>
</kbd>

## Folders

```text

├── pong_exp                                # Experiments folder
├── survey                                  # LaTeX survey
|── Learning_Agents_for_Pong__A_Survey.pdf  # PDF survey
|── quality.csv                             # A quality matrix
└── pong.nlogo                              # Actual code
```

# PLAY

If you want to see how an agent plays pong against a Scripted AI just do `SETUP`, `LOAD` (optional) and then `PLAY`.
This way the agent is not learning but simply playing the best action based on the quality matrix (quality.csv).
If you don't press `LOAD` the agent operates with an empty quality matrix (zeros only).
In the `pong_exp` folder you can find quality matrices (quality_20k_episodes_rnd-prob-0.1.csv, etc.). By renaming them to `quality.csv` and putting them in the directory where the netlogo code is (pong.nlogo) you can see how the agent plays.

# LEARN

You can generate your own quality matrix by doing `SETUP`, `LOAD` (optional), select the `algorithm` between SARSA and Q-Learning and then press `LEARN`.
This way the agent is learning and generating a quality matrix (quality.csv).
If you don't press `LOAD` the learning starts with an empty quality matrix (zeros only).

# CONFIGURATION

## Algorithm

You can choose whether the learning algorithm will be `Q-Learning` or `SARSA`.

## State-type

You can choose whether, during learning, the opponent's state, that is the coordinate x, is known to the agent or not.

## Reward-type

You can choose between two types of rewards.
The `basic` reward is a reward that gives +100 in case of victory, -100 in case of defeat and +1 for every time the paddle touch the ball.
The reward `distance` is based the basic reward but it also takes into accout the distance of the ball bounce from the center of the paddle.
