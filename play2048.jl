using jb2048
# Alt-m julia set working module

g=initgame()
initplot()
play!(g, display=true)
play!(g, display=true, target=(9,4))
play!(g, display=false, moves=250)
play!(g, display=true, moves=1)

gamma

staticeval(g.board)
[maxeval(g.board,k).score for k in 1:5]

length(staticache), length(meancache)
h,m=hits_staticache, misses_staticache
h/m
h,m=hits_meancache, misses_meancache
h/m
empty!(staticache);empty!(meancache)

i = -4
i -= 1;plot(g.hist[i]...)   # "splat" argument (aplati, écrasé)
i += 1;plot(g.hist[i]...)
e=evals(g.hist[i][1],3)
e[2:4,2:3]
evals(g.board,2)
g.hist[i]
back!(g,i)

b,move=[13 10 6 2; 9 7 4 1; 3 3 4 1; 2 0 0 0], 4529
g=Game(b)
g.move = move
plot(g)
setgamma()

back!(g,-1);plot(g)
computedepth(g.board)
maxeval(g.board,2)

play!(g, moves=1024)
plot(g)
g.motion

@time m,r,hg = repartition(10)
g=hg[9]

setcareful(3,6,3,100)
g=Game([13 11 9 5; 12 10 6 3; 3 4 3 2; 2 2 2 0])
@time m,r,hg = repartition(2,game=g,target=(14,1))
maximum(g.move for g in hg)
