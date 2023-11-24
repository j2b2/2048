# 2048
2048 Game
This module allows playing (automatically) the 2048 game, using Julia; it requires the package PyPlot, and is stored in the file jb2048.jl.
Using the REPL, a typical session looks like the following :

julia> using jb2048

julia> g=initgame()
Game [0 0 0 0; 1 0 1 0; 0 0 0 0; 0 0 0 0], move 2

julia> initplot()
PyPlot.Figure(PyObject <matplotlib.figure.Figure object at 0x7fc985e43208>)

julia> play!(g,display=true)
Such a game achieves an average move rate of 4 moves per second, on a very old processor. Hence a "good" play can last an hour.

It uses recursive search (expectimax algorithm) over a dag, whose endpoints are evaluated by the function staticeval().
This function uses a weighting symmetric matrix gamma, that promotes large tiles in the upper left corner,
and it computes penalties for couples of consecutive bad ordered values.
Each evaluation function returns a structure Estimation with two fields, val and score,
the second one being computed along the rules of the game, when two tiles merge.
