using jb2048
# julia set working module -> jb2048
g=initgame()
initplot()
play!(g, display=true)
play!(g, display=true, target=(10,2))
play!(g, display=true, moves=1)

i = 0
i -= 1;plot(g.hist[i]...)   # "splat" argument (aplati, écrasé)
i += 1;plot(g.hist[i]...)
e=evals(g.hist[i][1],3)
e[2:4,2:3]
evals(g.board,2)

b=[12 11 6 3; 9 8 6 2; 5 2 0 1; 0 0 1 2]
g=Game(b)
g.move = round(sum(1 << k for k in b) / 2.2)
plot(g)
setcareful(3, 4)
setgamma()

back!(g,-1);plot(g)
computedepth(g.board)
maxeval(g.board,2)

play!(g, moves=1024)
plot(g)
g.motion

@time m,r,hg = repartition(10)
g=hg[9]

setcareful(4, 5)
g=Game([13 11 9 5; 12 10 6 3; 3 4 3 2; 2 2 2 0])
@time m,r,hg = repartition(2,game=g,target=(14,1))
maximum(g.move for g in hg)
