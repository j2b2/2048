using jb2048
# julia set working module -> jb2048
g=initgame()
initplot()

b=[12 11 6 3; 9 8 6 2; 5 2 0 1; 0 0 1 2]
g=Game(b)
g.move = round(sum(1 << k for k in b) / 2.2)
plot(g)
setcareful(3, 4)
static
setgamma()
gamma

play!(g, display=true)
play!(g, display=true, target=(7,7))

play!(g, display=true, moves=1)
back!(g,-1);plot(g)
computedepth(g.board)
maxeval(g.board,2)
g.depth

play!(g, moves=1024)
g.motion
g.motion[5]/g.move

@time m,r,hg = repartition(10)
g=hg[9]

maxeval(g.board,1)
meaneval(g.board,1)
staticeval(g.board)
computedepth(g.board)
plot(g)
g.depth
g.board
move!(g,1)
back!(g,-1)
println(g)
b=[11 9 0 1; 10 8 0 0; 2 7 7 3; 1 2 2 2]

i = 0
i -= 1;plot(g.hist[i]...)   # "splat" argument (aplati, écrasé)
i += 1;plot(g.hist[i]...)
e=evals(g.hist[i][1],3)
e[2:4,2:3]
evals(g.board,2)
back!(g,i)
g[1,4]=2
force!(g,3)
println(g.hist[i])
typeof(g.hist[i])
staticeval(g.hist[i][1])

gamma[3:4,3:4] .= 0
gamma /= 2

setcareful(4, 4)
g=Game([13 11 9 5; 12 10 6 3; 3 4 3 2; 2 2 2 0])
@time m,r,hg = repartition(2,game=g,target=(14,1))
maximum(g.move for g in hg)

using BenchmarkTools
@btime staticeval(b)

empty!(staticache)
empty!(meancache)

b=[13 9 2 0; 8 7 1 0; 4 1 4 0;2 1 0 0]
staticeval(b)
g=Game(b)
e=evals(b,4)
e[2:4,3:4]
plot(g)
move!(g,true)
force!(g,3)
play!(g,display=true,moves=1)
play!(g,display=true)
