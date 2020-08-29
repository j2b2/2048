"""
    * 15 juin 2020 `staticeval()` utilise les paramètres static[2] (near)
    et static[3] (empty). `updateworse()` tient compte de empty,
    sinon la partie peut se bloquer (toutes les évaluations sont pires
    que `worse_eval`)
    * 16 juin ajout fonction `emptycells()` utilisée par `staticeval()`
    et `updateworse()`
    * 20 juillet la fonction `emptycells()` n'est plus utilisée,
    et `static` devient un couple. Un bonus pour le nombre de cellules
    libres est pourtant l'une des heuristiques du post
    stackoverflow "optimal algorithm for the game 2048"
    * 31 juillet calcul `depth` simplifié, utilise la tuile 128.
    * 2 août remplacement de `static` par trois constantes
    `sq, near, vs` : nette accélération des calculs.
    * 5 août `near` inutilisé (passé en commentaire), suppression
    des copies de boards dans `move!`
    * 7 août `Estimation` n'est plus mutable, sinon les caches
    sont modifiés subrepticement. En prime programme plus rapide,
    et `g.motion` enfin symétrique.
    * 10 août `vs` remplacé par `sw` (score's weight)
    * 22 août `depth` borné par 6
    * 23 août `meaneval(b,1)` remplace `staticeval(b)` pour
    détecter une fusion proche pendant le calcul de `depth`
    * 24 août `g.motion` réduit à un vecteur de 4 éléments,
    puisque le nombre de cellules vides n'est plus utilisé.
    * 25 août, introduction de `computedepth`, amélioration
    de l'affichage de `depth` dans `play!`, pour que la valeur
    visible soit bien celle du mouvement en cours
"""
module jb2048

import PyPlot
const plt = PyPlot

# used by dag2048.jl
export Board, Game, History, plot, record, slide, tileinsert!, back!

"Board=puzzle"
const Board = Matrix{Int}

plotcolor = ["white", "lightyellow", "orange", "orange",
             "tomato", "tomato", "yellow", "yellow",
             "gold", "gold", "peru", "chocolate",
             "orangered", "red", "red"]
plotstyle = Dict("alpha"=>0.5, "boxstyle"=>"round")

function initplot(m = 4, n = 4, figwidth = 7, figheight = 5)
    plt.pygui(true)
    fig=plt.figure("2048", figsize = (figwidth, figheight))
    plt.subplots_adjust(left=0.02, right=0.98, bottom=0.02, top=0.92)
    plt.gcf()
end

"""
    plot(b::Board [, newtile, depth, move])

Plot a board.
Optional argument `newtile` is the index of a tile
to be singled out (green color). Other optional arguments
are displayed on figure's title.
"""
function plot(b::Board, newtile=CartesianIndex(1,1), depth=0, move=0)
    fs = 36 # font size
    m, n = size(b)
    plt.cla()
    plt.axis([0.5, n + 0.5, 0.5, m + 0.5])
    plt.xticks([])
    plt.yticks([])
    depth > 0 && plt.title("Depth $depth", loc="left")
    move > 0 && plt.title("Move $move", loc="right")
    lp = length(plotcolor)
    for i in 1:m
        for j in 1:n
            t = b[i,j]
            t == 0 && continue
            if 0 < t <= lp
                k = CartesianIndex(i, j)
                plotstyle["facecolor"] =
                    (k == newtile) ? "lightgreen" : plotcolor[t]
                t = 1 << t
            else
                plotstyle["facecolor"] = "lightcyan"
            end
            plt.text(j, m + 1 - i, t,
                ha = "center", va = "center",
                size = fs, bbox = plotstyle)
        end
    end
    plt.draw()
    plt.pause(0.01) # nécessaire, sinon rien n'est affiché
end

"""
    tileinsert!(b::Board)

Insert a random new tile into a board.
"""
function tileinsert!(b::Board)
    u = findall(b .== 0)  # indices of free cells
    i = u[rand(1:end)]
    t = rand() < 0.9 ? 1 : 2
    b[i] = t
    i
end

"""
    slide(b::Board, direction:: Int)

Slide a board `b` in one of the four directions (1=left, 2=right, 3=up, 4=down),
and merge equal tiles, along the rules of 2048 game.

Return a tuple `(rb,score,moved)` where:
  * `rb` is the resulting board
  * `score` is the sum of the values of merged tiles
  * `moved` is a boolean that reports whether the initial board `b`
    and the new one `rb` are distinct, i.e. whether the move is legal.
"""
slide(b::Board, direction:: Int) = dslide(b, direction)

# Two versions of slide
function dslide(b::Board, direction:: Int)
    # direct slide, with code duplication
    m, n = size(b)
    r = zero(b)
    score = 0
    moved = false
    if direction < 3    # horizontal slide
        (direction == 1) ? (start = 1; delta = 1) : (start = n; delta = -1)
        for i in 1:m
            j = target = start
            t0 = 0
            for k in 1:n
                @inbounds t = b[i,j]
                if t > 0
                    if t == t0  # tiles merge
                        t += 1
                        target -= delta
                        t0 = 0
                        score += 1 << t
                    else
                        t0 = t
                    end
                    @inbounds r[i,target] = t
                    target == j || (moved = true)
                    target += delta
                end
                j += delta
            end
        end
    else    # vertical slide
        (direction == 3) ? (start = 1; delta = 1) : (start = m; delta = -1)
        for j in 1:n
            i = target = start
            t0 = 0
            for k in 1:m
                @inbounds t = b[i,j]
                # if t != 0
                if t > 0
                    if t == t0  # tiles merge
                        t += 1
                        target -= delta
                        t0 = 0
                        score += 1 << t
                    else
                        t0 = t
                    end
                    @inbounds r[target,j] = t
                    target == i || (moved = true)
                    target += delta
                end
                i += delta
            end
        end
    end
    return r, score, moved
end

function tslide(b::Board, direction:: Int)
    # use transposition
    # no code duplication, but almost three times slower :-(
    if direction < 3    # horizontal slide
        m, n = size(b)
        rb = zero(b)
        score = 0
        moved = false
        (direction == 1) ? (start = 1; delta = 1) : (start = n; delta = -1)
        for i in 1:m
            j = target = start
            t0 = 0
            @inbounds(for k in 1:n
                t = b[i,j]
                if t > 0
                    if t == t0  # tiles merge
                        t += 1
                        target -= delta
                        t0 = 0
                        score += 1 << t
                    else
                        t0 = t
                    end
                    rb[i,target] = t
                    target == j || (moved = true)
                    target += delta
                end
                j += delta
            end)
        end
        return rb, score, moved
    else    # vertical slide
        b = permutedims(b)
        rb, score, moved = tslide(b, direction-2)
        return permutedims(rb), score, moved
    end
end

# gamma = [10 6 4 3; 6 4 3 2; 4 3 2 1.42; 3 2 1.42 1]
# gamma = 0.25 * [64 32 16 8; 32 12 6 4; 16 6 3 2; 8 4 2 1]
# gamma = 0.5 * [14 12 10 8; 12 9 6 4; 10 6 3 2; 8 4 2 1]

function setgamma(weights::Matrix{Float64})
    global gamma = weights
end

setgamma() = setgamma([16.0 12 8 6; 12 10 3 2; 8 3 1 0; 6 2 0 0])
# setgamma() = setgamma([16 12 8 4; 12 10 5 2; 8 5 3 1; 4 2 1 0.5])
# setgamma() = setgamma([16 12 8 4; 12 6 3 2; 8 3 1 0.5; 4 2 0.5 0.5])

struct Estimation
    val::Float64
    score::Int
end

function Base.:<(e1::Estimation, e2::Estimation)
    # vs = static[3]  # val versus score
    e1.val + sw * e1.score < e2.val + sw * e2.score
end

# Beaucoup plus rapide que setstatic() etc.
# sq = squeeze, sw = score's weight
const sq, sw = 16, 2

function emptycells(b::Board)
    z = count(b .== 0)
    static[3] * 1<<(z-3)
end

# worse_eval = -128.0
function updateworse(b::Board)
    sup = maximum(b)
    global worse_eval = - (1 << sup) * gamma[1]
    # worse_eval -= emptycells(b)
end

staticache = Dict{UInt64,Estimation}()
hits_staticache = misses_staticache = 0

"""
    staticeval(b::Board)

Return the static evaluation of a board.
Use the global weighting matrix `gamma`,
and a tuple of static parameters.
"""
function staticeval(b::Board)
    ### cache
    ### It's a little faster to store only a key in the cache,
    ### instead of the matrix b, and it's safe in this context
    global hits_staticache, misses_staticache
    key = hash(b)
    e = get(staticache, key, Estimation(0.0, -1))
    # println(b)
    # println(length(staticache)," ",e)
    e.score == -1 || (hits_staticache += 1; return e)
    ### end cache

    val = sum(1<<b[i] * gamma[i] for i in LinearIndices(b))
    score = 0
    m, n = size(b)
    x = b[1]
    # first column
    # sq = squeeze
    for i in 2:m
        @inbounds y = b[i, 1]
        if y > 0
            if x == y
                score += 2<<y
            elseif 0 < x < y    # y squeezes x
                val += sq * (1<<x - 1<<y)
        #     # elseif x == y + 1
        #     #     val += near * 1<<y
            end
        end
        x = y
    end
    # first row
    x = b[1]
    for j in 2:n
        @inbounds y = b[1, j]
        if y > 0
            if x == y
                score += 2<<y
            elseif 0 < x < y    # y squeezes x
                val += sq * (1<<x - 1<<y)
        #     # elseif x == y + 1
        #     #     val += near * 1<<y
            end
        end
        x = y
    end

    # inner tiles
    for j in 2:n
        # @inbounds efficace (test)
        @inbounds x1 = b[1, j]
        for i in 2:m
            @inbounds y = b[i, j]
            if y > 0
                @inbounds x2 = b[i, j - 1]
                (x1 == y || x2 == y) && (score += 2<<y)
                0 < x1 < y && (val += sq * (1<<x1 - 1<<y))
                0 < x2 < y && (val += sq * (1<<x2 - 1<<y))
                # x1 == y + 1 && (val += near * 1<<y)
                # x2 == y + 1 && (val += near * 1<<y)
            end
            x1 = y
        end
    end
    # val += emptycells(b)
    e = Estimation(val, score)
    ### cache
    misses_staticache += 1
    staticache[key] = e
    ### end cache
    return e
end

"""
    maxeval(b::Board, depth::Int)

Return the recursive estimation of the best move
(via calls to `meaneval`), up to the required depth.
"""
function maxeval(b::Board, depth::Int)
    bestestim = Estimation(worse_eval, 0)
    for dir = 1:4
        bs, sc, moved = slide(b, dir)
        if moved
            bs[1] == 0 && continue
            e = meaneval(bs, depth - 1)
            val = e.val
            score = e.score + sc
            e = Estimation(val, score)
            bestestim < e && (bestestim = e)
        end
    end
    bestestim
end

# meancache = Dict{(Board,Int,Int),Float64}()
meancache = Dict{UInt64, Estimation}()
hits_meancache = misses_meancache = 0

"""
    meaneval(b::Board, depth::Int)

Return `staticeval(b)` if `depth <= 0`.
Otherwise, for each board resulting of the insertion of a new tile in `b`:
  * evaluate it via a recursive call to `maxeval`, up to the required depth
  * return the average evaluation, with uniform weight
    for each free cell in `b`, and 0.9 weight (resp. 0.1)
    when inserting the tile 2 (resp. 4).
"""
function meaneval(b::Board, depth::Int)
    depth <= 0 && return staticeval(b)
    ### cache
    # It's a little faster to store only a key in the cache,
    # instead of (b,depth,score), and it's safe in this context
    global hits_meancache, misses_meancache
    key = hash((b,depth))
    e = get(meancache, key, Estimation(0.0, -1))
    e.score == -1 || (hits_meancache += 1; return e)
    ## end cache

    fc = findall(b .== 0)  # indices of free cells
    nf = length(fc)
    if nf == 0
        return Estimation(worse_eval, 0)
    end
    val = 0.0
    score = 0.0
    for i in fc
        b[i] = 1
        e = maxeval(b, depth)
        val += 0.9 * e.val
        score += 0.9 * e.score
        b[i] = 2
        e = maxeval(b, depth)
        val += 0.1 * e.val
        score += 0.1 * e.score
        b[i] = 0
    end
    val = val / nf
    score = round(score / nf)
    e = Estimation(val, score)
    ### cache
    misses_meancache += 1
    meancache[key] = e
    ### end cache
    return e
end

mutable struct History
    length::Int
    circular::Int
    start::Int
    board::Vector{Board}
    newtile::Vector{CartesianIndex{2}}
    depth::Vector{Int}

    function History(length)
        circular = 0
        start = 1
        board = Vector{Board}(undef, length)
        newtile = Vector{CartesianIndex{2}}(undef, length)
        depth = Vector{Int}(undef, length)
        new(length, circular, start, board, newtile, depth)
    end
end

# import Base.show
function Base.show(io::IO, h::History)
    print(io, "Circular history: start $(h.start) -> current $(h.circular), length $(h.length)")
end

function record(h::History, b::Board, t::CartesianIndex{2}, d::Int)
    # first values of (start,circular) for length 128, phase 1:
    #  (1,0) -> (1,1) -> (1,2) -> (1,3) ... -> (1,127) -> (1,128)
    # now buffer is full, transition to phase 2 occurs: (1,128) -> (2,1)
    # values of (circular,start) during phase 2:
    #  (1,2) -> (2,3) -> (3,4) ... -> (127, 128) -> (128,1) -> (1,2)
    h.circular += 1
    if h.circular > h.length
        h.circular = 1
        h.start = 2
    elseif h.start > 1
        # steady state, full circular buffer
        h.start += 1
        h.start > h.length && (h.start = 1)
    end
    i = h.circular
    h.board[i] = copy(b)
    h.newtile[i], h.depth[i] = t, d
end

# import Base.getindex, Base.setindex!
function Base.getindex(h::History, i::Int)
    n = lastindex(h)
    i = mod(h.start + i - 2, n) + 1
    h.board[i], h.newtile[i], h.depth[i]
end

# import Base.endof
function Base.lastindex(h::History)
    h.start == 1 ? h.circular : h.length
end

"""
A game `g` has six fields:
  * `board`: a matrix that records game's tiles
  * `newtile`: an index that records the last tile inserted by `tileinsert!()`
  * `depth`: the recursive depth computed by `move!()`
  * `move`: number of moves
  * `motion`: expanded information about moves (directions)
  * `hist`: a circular buffer that stores a (partial) game's history
"""
mutable struct Game
    board::Board
    newtile::CartesianIndex{2}
    depth::Int
    move::Int
    motion::Vector{Int}
    hist::History

    function Game(board)
        new(board, CartesianIndex(1, 1), 0, 0, zeros(Int, 4), History(128))
    end
end
record(g::Game) = record(g.hist, g.board, g.newtile, g.depth)

function Base.show(io::IO, g::Game)
    print(io, "Game ", g.board, ", move ", g.move)
end

Base.getindex(g::Game, i...) = g.board[i...]
Base.setindex!(g::Game, x, i...) = Base.setindex!(g.board, x, i...)
Base.lastindex(g::Game) = Base.lastindex(g.board)

"""
    plot(g::Game)

Shortcut for plotting `g.board`, with `g.newtile` singled out,
and `g.depth`, `g.move` displayed as title
"""
function plot(g::Game)
    plot(g.board, g.newtile, g.depth, g.move)
end

function initgame()
    m, n = size(gamma)
    b = zeros(Int, m, n)
    g = Game(b)
    tileinsert!(g.board)
    g.newtile = tileinsert!(g.board)
    g.move = 2
    g.depth = careful[1]
    g
end

"""
    setcareful(d::Tuple{Int, Int})

Set couple of parameters for computation of the recursive depth:
(initial depth, position of tile 64 that triggers depth's incrementation)
"""
function setcareful(d::Tuple{Int, Int})
    global careful = d
end

setcareful(a::Int, b::Int) = setcareful((a, b))

setcareful() = setcareful(3, 3)

"""
    computedepth(b::Board)

Compute recursive evaluation's depth, initially first
careful's value, and then incremented it the number of
large tiles is greater than second careful's value.
No incrementation if there are tiles to be merged quickly.
"""
function computedepth(b::Board)
    initd, quiet = careful
    depth = initd
    updateworse(b)
    # les choix ci-dessous accélèrent de plus en plus les calculs
    # au prix d'une diminution de la longueur moyenne des parties
    # (profondeur d'exploration insuffisante)
        # e = staticeval(b)
        # e = maxeval(b, 1)
        # e = maxeval(b, 2)
        # e = maxeval(b, initd)
    e = staticeval(b)
    if e.score < 64
        large = count(b .> 6)
        large > quiet && (depth += large - quiet)
        depth > 6 && (depth = 6)
    end
    depth
end

"""
    move!(g::Game, depth::Int=0)

Compute the direction `bestdir` of the slide with best evaluation,
using recursive evaluation, tuned by the optional argument `depth`
If this direction is zero, there is no legal move,
otherwise `g.board` and `g.move` are updated.
Return `bestdir`.
"""
function move!(g::Game, depth::Int)
    empty!(staticache)
    empty!(meancache)
    b = g.board
    updateworse(b)
    ### compute best move
    bestestim = Estimation(worse_eval, 0)
    bestdir = 0
    local newboard::Board
    for dir = 1:4
        bs, sc, moved = slide(b, dir)
        if moved
            d = depth
            bs[1] == 0 && (d = 1)
            e = meaneval(bs, d)
            val = e.val
            score = e.score + sc
            e = Estimation(val, score)
            if bestestim < e
                bestestim = e
                bestdir = dir
                # newboard = copy(bs)
                newboard = bs
            end
        end
    end
    if bestdir > 0
        # g.board = copy(newboard)
        g.board = newboard
        g.move += 1
        g.motion[bestdir] += 1
        # g.motion[5] += count(g.board .== 0)
    end
    bestdir
end

"""
    freeze(b::Board, d::Int)

Experimental. Return the vector of cartesian coordinates of cells that may be frozen.
Argument `d` is the minimal value of frozen tiles;
it is incremented until all frozen tiles are distinct.
Finally return the coordinates of the largest included *partition*.

# Examples
```
julia> freeze([6 5 3; 4 2 2], 4)
3-element Array{CartesianIndex{2},1}:
 CartesianIndex(1, 1)
 CartesianIndex(2, 1)
 CartesianIndex(1, 2)

julia> freeze([6 5 4; 4 2 2], 4)
2-element Array{CartesianIndex{2},1}:
 CartesianIndex(1, 1)
 CartesianIndex(1, 2)
```
For the second example, indices `(1, 3)` and `(2, 1)`
are not frozen, because corresponding values are equal
(and may be merged soon).
```
julia> freeze([6 5 3; 2 4 2], 4)
2-element Array{CartesianIndex{2},1}:
 CartesianIndex(1, 1)
 CartesianIndex(1, 2)
```

Here index `(2, 2)` is not frozen, otherwise the frozen region
would not be a partition.
```
julia> freeze([3 5 2; 1 4 2], 4)
0-element Array{CartesianIndex{2},1}
```
"""
function freeze(b::Board, d::Int)
    ifrozen = findall(b .>= d)
    n = length(ifrozen)
    if n > 1
        u = sort(b[ifrozen], rev = true)
        for i in 1 : n - 1
            # @inbounds useless (test btime)
            if u[i] == u[i + 1]
                d = u[i] + 1
                ifrozen = findall(b .>= d)
                break
            end
        end
    end
    # ifree = findall(b .< d)
    n = length(ifrozen)
    n == 0 && return ifrozen
    ifrozen[1] != CartesianIndex(1, 1) && return CartesianIndex{2}[]
    u = falses(n)
    i0, j0 = 0, 1
    i1 = size(b)[1]
    for (k, c) in enumerate(ifrozen)
        i, j = Tuple(c)
        if j == j0
            if i == i0 + 1 && i <= i1
                i0 += 1
                u[k] = true
            end
        elseif i == 1 && j == j0 + 1
            i1 = i0
            i0, j0 = i, j
            u[k] = true
        else
            break
        end
    end
    ifrozen[u]
end

"""
    play!(g::Game; display=false, moves=32768, target=(16,1))

Play a game, with current state of `g` as starting point.
If keyword argument `display` is `true`, `g` is plotted after each move.
The number of moves may be bounded by the optional keyword argument `moves`,
thereafter the game stops
-- and may be resumed by issuing again `play!(g)`.
Another optional keyword argument `target` is a couple `(t,p)`
that stops the game
as soon as the tile `t` appears in "position" `p`
(i.e. size of the greatest *partition* inside the region made up of
distinct cells with value at least `t`, see function `freeze()`).
"""
function play!(g::Game; display::Bool=false, moves::Int=32768, target::Tuple{Int,Int}=(16,1))
    global gamma
    global hits_meancache, misses_meancache
    global hits_staticeval, misses_staticeval
    n = g.move
    if n < 2
        hits_meancache = misses_meancache = 0
        hits_staticeval = misses_staticeval = 0
        g.hist = History(128)
        record(g.hist, g.board, CartesianIndex(1,1), 0)
    end
    t, p = target   # target value, position
    # println("careful=$careful static=$static")
    while g.move < n + moves
        if t < 16   # otherwise target unreachable
            ifrozen = freeze(g.board, t)
            length(ifrozen) >= p && break
        end
        d = computedepth(g.board)
        if d != g.depth
            if display
                plt.title("Depth $d", loc="left", color="blue")
                # nécessaire pour affichage en temps réel :
                plt.pause(0.01)
            end
            g.depth = d
        end
        move!(g, d) > 0 || break
        g.newtile = tileinsert!(g.board)
        display && plot(g)
        record(g)
    end
    display && plot(g)
    return
end

"""
    back!(g::Game, i)

Restore the game `g` to a previous state.
The integer `i` is an index in the circular buffer `g.hist`:

    back!(g,-1) # cancel the last move
    back!(g, 1) # restore the game at the beginning of the history

Caution: `g.hist` is not updated.
"""
function back!(g::Game, i)
    g.board, g.newtile = g.hist[i][1:2]
    n = lastindex(g.hist)
    g.move += mod1(i, n) - n
end

"""
    force!(g::Game, dir::Int)

Force a move in the required direction (without updating history),
and plot the result:

    force!(g,3) # force a move up
"""
function force!(g::Game, dir::Int)
    b, score, moved = slide(g.board, dir)
    moved || error("Illegal direction")
    g.board = b
    g.newtile = tileinsert!(b)
    plot(g)
    score
end

"""
    evals(b::Board, depth)

Return a matrix `u`, where `u[i,j]` is the evaluation of move `i`
(i.e. in the direction `i`) up to depth `j`.
"""
function evals(b::Board, depth::Int)
    empty!(staticache)
    empty!(meancache)
    u = Matrix{Estimation}(undef, 4, depth)
    for dir = 1:4
        bs, score, moved = slide(b, dir)
        if moved
            for k = 1:depth
                e = meaneval(bs, k)
                u[dir,k] = e
            end
        end
    end
    u
end

"""
    repartition(n; board = nothing, verbose = true)

Play `n` games and return a tuple of statistics:
  * average number of moves
  * an array `hsup`, where hsup[i] is the number of games that halted
    with 2^i as the largest tile
  * an array of the games played (including their histories).

Optional keyword argument `board` specifies the starting board.
If `verbose` is true, each played game is displayed when it halts,
as well as the current average number of moves, and `hsup[10:15]`,
ie. an array filled with
the number of games that reached so far 1K, 2K, 4K ... 32K.
"""
function repartition(n; game = nothing, verbose = true, target = (16, 1))
    # verbose && println("gamma = $gamma")
    # verbose && println("careful = $careful static = $static")
    verbose && print("careful = $careful ")
    verbose && println("sq, sw = $sq, $sw")
    hsup = zeros(Int, 16)
    nmoves = 0
    hgames = Vector{Game}(undef, n)
    local hmoves
    for i = 1 : n
        g = (game == nothing) ? initgame() : deepcopy(game)
        play!(g, target = target)
        nmoves += g.move
        sup = maximum(g.board)
        hsup[sup] += 1
        hmoves = div(nmoves,i)
        if verbose
            println("$i: $g")
            println("$hmoves $(hsup[10:15])")
        end
        hgames[i] = g
    end
    hmoves, hsup, hgames
end

"""
    moves4(g::Game)

Compute and return the number of moves where the new tile's value was 4.
"""
function moves4(g::Game)
    sigma = sum(2^k for k in g.board if k>0)
    m = div(sigma, 2) - g.move
end

"""
    score(g::Game)

Compute and return the usual score.
"""
function score(g::Game)
    m = moves4(g)
    s2 = sum((k-1)*2^k for k in g.board if k>0)
    s2 - 4*m
end

function score_to_moves(b::Board, s::Integer)
    sigma = sum(2^k for k in b if k>0)
    s2 = sum((k-1)*2^k for k in b if k>1)
    m = div(s2 - s, 4)
    n = div(sigma, 2) - m
    m, n
end

setgamma()
# setstatic()
setcareful()
end
