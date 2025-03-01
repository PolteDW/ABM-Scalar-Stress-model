# ABM scalar stress model
An agent-based model to explore the scalar stress buildup process in a community

This NetLogo-based Agent-Based Model (ABM) simulates the buildup of scalar stress within a community through dynamic social interactions. The model is designed to explore how factors like interaction fatigue and happiness influence community stability and social complexity.

## **Model Overview**

The Scalar Stress ABM creates a simulated environment where agents (representing individuals) interact within with each other. The interactions contribute to a cumulative measure of scalar stress, which serves as an indicator of the community's social pressure and need for reorganization.

## **Key Features**

- **Family-Based Social Interactions:** Agents belong to distinct family units and interact based on proximity and family cohesion.
- **Mood and Fatigue Dynamics:** Agents' moods change with interactions, and interaction fatigue influences their willingness to engage with others.
- **Scalar Stress Calculation:** The model tracks interactions over a user-defined timeframe to calculate scalar stress, with a warning triggered if the stress exceeds a critical threshold.
- **Customizable Parameters:** Users can adjust **family size**, **number of families**, **attraction radius**, **interaction radius**, **mood and fatigue influence**, and **scalar stress threshold**.
- **Data Visualization:** Real-time plots show **global interactions**, **scalar stress evolution**, **agent mood distribution**, and **interaction fatigue**.

## **How to Use the Model**

1. **Setup the Model:** Click the `setup` button to initialize agents, family centers, and the environment.
2. **Run the Simulation:** Press the `go` button to start the simulation. The model will continue to run until the scalar stress threshold is reached.
3. **Adjust Parameters:** Use the sliders to influence the community dynamics:
   - `Family-size` and `Family-count` define the **population structure**.
   - `Attraction-Radius` and `family-cohesion` affect **movement** and **interaction likelihood**.
   - `Mood-weight` and `Fatigue-weight` determine how these factors influence **scalar stress**.
   - `Scalar-stress-threshold` sets the **critical point for community reorganization**.

## **Installation**

1. Download and install NetLogo from [NetLogo's official site](https://ccl.northwestern.edu/netlogo/download.shtml).
2. Open the `.nlogo` file in NetLogo.
3. Configure parameters using the **sliders** and **buttons** in the interface.

## **Output and Analysis**

The model generates the following visual outputs:

- **Global Interactions Over Time:** Shows the **cumulative count of social interactions**.
- **Scalar Stress Evolution:** Visualizes **stress levels** and the **approach to the threshold**.
- **Mood Distribution:** Highlights the **overall sentiment of agents**.
- **Fatigue Distribution:** Tracks how **interaction fatigue** spreads among agents.

## **Contributors**

Developed by **Polte De Weirdt**, under guidance of **Dries Daems**.
