# LogicGames
Development environment for creating and testing logic game algorithms

This project started in 1998 as part of my master thesis on "Specification Language for Logic Games". 
The scope of the thesis was to design a formal language in which the rules of various logic games such as chess, checkers, go, etc. could be easily defined.
In principle, the rules of logic games specify in which states a game can be in, or if it is in some state X, to which possible states Y1..Yn the game can continue.
So I have chosen the simplest set of procedures that generate a complete tree for a given type of game. These procedures are:
- GenerStartPositions
- GenerPositions(p as Position)
  
"Position" is some particular state of the game.
These functions create new positions by calling the system procedure NewMove, which takes as parameters a new position and its (trivial) valuation.

As part of my thesis, I also developed an environment in which logic games can be defined using the above procedures in a simple procedural language resembling Pascal or Basic, but then also played. 
The program traverses the game tree using the MiniMax or AlphaBeta algorithm to find the best move for the player who is on the turn. 
The game can be played human against computer, or human against human, or computer against computer.

The defined procedures are translated into a special intermediate code (similar to how Java is translated into bytecode) and this intermediate code is executed in the simple virtual machine created. 
It also includes a simple editor, a debugger with breakpoints, expression evaluation (watch list), etc.

I've also implemented some optimizations to the intermediate code, but more can definitely be added. 
The modules for compiling and running code should be usable in other projects, or will be possible after modifications to resolve interdependencies between the project modules.

You can try to play several logic games that I have defined (programmed) in this system, or you can create your own. 

I recently migrated the project to the current Embarcadero Delphi 10.4 Community version.
