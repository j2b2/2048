include("jb2048.jl")
using CPUTime, .jb2048

g=initgame()
initplot()
setcareful(3,6,3)
play!(g, display=true)
play!(g, display=true, target=(7,4))
@CPUtime play!(g, display=true, moves=250)
play!(g, display=true, moves=1)
g.motion
g[end]=2

i = 0
i += 1;plot(g.hist[i])
g.hist[i]
back!(g,i)
force!(g,1)
[maxeval(g.hist[i].board,k).score for k in 1:3]

g=initgame()
@CPUtime @quiet xplay!(g, 2, display=true)

GC.gc()
jb2048.gamma

staticeval(g.board)

length(staticache), length(meancache)
h,m=hits_staticache, misses_staticache
h/m
h,m=hits_meancache, misses_meancache
h/m
empty!(staticache);empty!(meancache)

computedepth(g)
maxeval(g.board,2)

b,move=[13 10 6 2; 9 7 4 1; 3 3 4 1; 2 0 0 0], 4529
g=Game(b)
g.move = move
g.newtile = CartesianIndex(3, 4)
plot(g)

@time m,r,hg = repartition(10)
g=hg[9]

g=Game([13 11 9 5; 12 10 6 3; 3 4 3 1; 2 1 2 0]); g.newtile=CartesianIndex(3,4)
@time m,r,hg = repartition(10,game=g,target=(14,1))
maximum(g.move for g in hg)
initplot()
plot(g)

jb2048.:+(3,4)
jb2048.sin(pi/6)