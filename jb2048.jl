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
    * 30 août Révision et test des documentations des fonctions
    * 26 septembre Ajout du champ `score` dans la structure `Game`,
    mis à jour par `move!` et utilisé par `computedepth`
    * 28 septembre, le score calculé par `staticeval`
    n'est plus utilisé par `meaneval`,
    sinon ce score est dupliqué par `maxeval`
    * 5 octobre, je découvre que `@time` utilise bêtement l'horloge,
    au lieu de retourner le temps CPU :-(
    * 6 octobre, `g.move` et `g.score` enregistrés dans l'historique
    * 9 octobre, fonction `meaneval()` accélérée :
    lorsque la profondeur de recherche `depth` est grande
    (supérieure à 5), elle est décrémentée si le nombre de cellules
    vides est supérieur à 2.
    * 10 octobre, `staticeval()` remaniée, la dernière ligne
    et la denière colonne ne sont plus ordonnées,
    ce sont de simples "réserves" ("stores"),
    dont les cellules n'ont plus de poids
    (`gamma` vaut 0 sur cette ligne et cette colonne extrêmes).
    * 13 octobre, fonction `update_worse()` supprimée au profit
    de la constante `sadestim`
    * 5 novembre, la fonction `setcareful()` est simplifiée;
    introduction des constantes `nfz` et `dfz` pour l'accélération
    de la fonction `meaneval()`
    * 26 novembre, les évaluations et la matrice `gamma` ne sont plus
    des flottants; voir en particulier la modification de la fonction
    `meaneval()`
    * 27 novembre, annulation de la modification du 28 septembre,
    qui semble erronée
    * 28 novembre, introduction de `struct Configuration`,
    de telle sorte qu'une `History` contienne un vecteur de configurations.
    Duplication de code inévitable avec `struct Game`, pour conserver
    dans les deux cas un accès direct aux champs `board`, `move`, etc.
    * 30 novembre, la fonction `plot` utilise la structure `Configuration`.
    * 2 décembre, la fonction `force(g, dir)` incrémente `g.move`
    et enregistre la nouvelle configuration dans l'historique.
    * 24 décembre 2020, fonction `staticeval()` modifiée pour tenter de
    prévenir les glissements intempestifs qui décollent du bord une grande tuile.
    * 5 janvier 2021, `move!` traite correctement les mouvements qui déplacent
    la tuile supérieure gauche ("bad moves"); ceux-ci sont pris en compte,
    mais seulement si nécessaire.
    * 20 février, `play!` retourne un booléen. Abandon d'Atom pour VS code.
"""

module jb2048

import PyPlot
const plt = PyPlot

# used by dag2048.jl
# export Board, Game, History, plot, record, slide, tileinsert!, back!
export Game, Configuration, plot, initgame, initplot,
    play!, back!, force!, xplay!, repartition,
    setcareful, setgamma, evals

# Plateau de jeu
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
    plot(b::Board [, newtile])

Plot a board. Optional argument `newtile` is the index of a tile
to be singled out (green color).
"""
function plot(b::Board, newtile=CartesianIndex(1,1))
    fs = 36 # font size
    m, n = size(b)
    plt.cla()
    plt.axis([0.5, n + 0.5, 0.5, m + 0.5])
    plt.xticks([])
    plt.yticks([])
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
    # plt.pause(0.01) # nécessaire, sinon rien n'est affiché
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

Slide a board `b` in one of the four directions
(1=left, 2=right, 3=up, 4=down),
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

function setgamma(weights::Matrix{Int})
    global gamma = weights
end

# setgamma() = setgamma([16 12 8 4; 12 10 2 0; 8 2 0 0; 4 0 0 0])
# setgamma() = setgamma([16 12 8 0; 12 10 6 0; 8 6 4 0; 0 0 0 0])
setgamma() = setgamma([16 12 8 4; 12 10 6 0; 8 6 0 0; 4 0 0 0])
# setgamma() = setgamma([16 12 8 4; 12 4 2 0; 8 2 0 0; 4 0 0 0])

struct Estimation
    val::Int
    score::Int
end

# simpler word than worse_estim :-)
const sadestim = Estimation(0, -1)

function Base.isless(e1::Estimation, e2::Estimation)
    e2.score < 0 && return false
    e1.score < 0 && return true
    # sw = score's weight
    e1.val + sw * e1.score < e2.val + sw * e2.score
end

# Much faster than setstatic() etc.
# sq = squeeze, sw = score's weight
const sq, sw = 12, 2

# function updateworse(b::Board)
#     sup = maximum(b)
#     global worse_eval = -(1 << sup) * gamma[1]
# end

staticache = Dict{UInt64,Estimation}()
hits_staticache = misses_staticache = 0

"""
    staticeval(b::Board)

Return the static evaluation of a board.
Use the global weighting matrix `gamma`,
and the constant `sq` that is a multiplicative
coefficient for the penalty inflicted on each
bad ordered pair of consecutive tiles.
"""
function staticeval(b::Board)
    ### cache
    ### It's a little faster to store only a key in the cache,
    ### instead of the matrix b, and it's safe in this context
    global hits_staticache, misses_staticache
    key = hash(b)
    e = get(staticache, key, sadestim)
    e.score < 0 || (hits_staticache += 1; return e)
    ### end cache

    val = sum(1<<b[i] * gamma[i] for i in LinearIndices(b))
    score = 0
    m, n = size(b)

    # rows, last one is a simple store
    for i in 1:m-1
        # @inbounds efficace (test)
        @inbounds x = b[i, 1]
        for j in 2:n
            @inbounds y = b[i, j]
            if y > 0
                if x == y
                    score += 2<<y
                elseif x == 0
                    j == 2 && (val -= sq * (2<<y))
                elseif x < y
                    val += sq * (1<<x - 1<<y)
                end
            end
            x = y
        end
    end
    # columns, last one is a simple store
    for j in 1:n-1
        # @inbounds efficace (test)
        @inbounds x = b[1, j]
        for i in 2:m
            @inbounds y = b[i, j]
            if y > 0
                if x == y
                    score += 2<<y
                elseif x == 0
                    i == 2 && (val -= sq * (2<<y))
                elseif x < y
                    val += sq * (1<<x - 1<<y)
                end
            end
            x = y
        end
    end
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
    bestestim = sadestim
    for dir = 1:4
        bs, sc, moved = slide(b, dir)
        if moved
            bs[1] == 0 && continue
            e = meaneval(bs, depth - 1)
            e = Estimation(e.val, e.score + sc)
            bestestim < e && (bestestim = e)
        end
    end
    bestestim
end

# meancache = Dict{(Board,Int,Int),Float64}()
meancache = Dict{UInt64, Estimation}()
hits_meancache = misses_meancache = 0

# fz = free zone
# const nfz, dfz = 3, 5

"""
    meaneval(b::Board, depth::Int)

Return `staticeval(b)` if `depth <= 0`.
Otherwise, for each board resulting of the insertion
of a new tile in `b`:
  * evaluate it via a recursive call to `maxeval`,
    up to the required depth
  * return the average evaluation, with uniform weight
    for each free cell in `b`, and 0.9 weight (resp. 0.1)
    when inserting the tile 2 (resp. 4).
"""
function meaneval(b::Board, depth::Int)
    # if depth <= 0
    #     e = staticeval(b)
    #     return Estimation(e.val, 0)
    # end
    depth <= 0 && return staticeval(b)
    ### cache
    # It's a little faster to store only a key in the cache,
    # instead of (b,depth), and it's safe in this context
    global hits_meancache, misses_meancache
    key = hash((b,depth))
    e = get(meancache, key, sadestim)
    e.score < 0 || (hits_meancache += 1; return e)
    ## end cache

    fc = findall(b .== 0)  # indices of free cells
    nf = length(fc)
    nf == 0 && return sadestim
    # accélération apparemment sensible -- 10% ?
    nf > 3 && depth > 5 && (depth -= 1)
    val::Float64 = 0.0
    score::Float64 = 0.0
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
    v = round(Int, val / nf)
    s = round(Int, score / nf)
    e = Estimation(v, s)
    ### cache
    misses_meancache += 1
    meancache[key] = e
    ### end cache
    return e
end

# Duplication de code avec la structure Game
# ne pas modifier l'un sans l'autre
struct Configuration
    board::Board
    newtile::CartesianIndex{2}
    move::Int
    depth::Int
    score::Int  # expected
end

"""
    plot(c::Configuration)

Plot `c.board`, with `g.newtile` singled out,
and `c.depth`, `c.move`, (expected) `c.score` displayed as title.
"""
function plot(c::Configuration)
    plot(c.board, c.newtile)
    plt.title("Move $(c.move)", loc="left")
    plt.title("Depth $(c.depth)", loc="center")
    plt.title("Expected score $(c.score)", loc="right")
    plt.pause(0.01) # nécessaire, sinon rien n'est affiché
end

mutable struct History
    length::Int
    circular::Int
    start::Int
    config::Vector{Configuration}

    function History(length)
        circular = 0
        start = 1
        c = Vector{Configuration}(undef, length)
        new(length, circular, start, c)
    end
end

# import Base.show
function Base.show(io::IO, h::History)
    print(io, "Circular history: start $(h.start) -> current $(h.circular), length $(h.length)")
end

function record(h::History, c::Configuration)
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
    h.config[i] = c
end

function Base.getindex(h::History, i::Int)
    n = lastindex(h)
    i = mod(h.start + i - 2, n) + 1
    h.config[i]
end

function Base.lastindex(h::History)
    h.start == 1 ? h.circular : h.length
end

"""
A game `g` has seven fields:
  * `board`, a matrix that records game's tiles
  * `newtile`, an index that records the last tile
  inserted by `tileinsert!()`
  * `move`, number of moves
  * `depth`, the recursive depth computed before a move
  * `score`, sum of expected mergings for the next `depth` moves
  * `motion`, expanded information about moves (directions)
  * `hist`, a circular buffer that stores a (partial) game's history
"""
mutable struct Game
    # Duplication de code avec la structure Configuration
    # ne pas modifier l'une sans l'autre
    board::Board
    newtile::CartesianIndex{2}
    move::Int
    depth::Int
    score::Int  # expected
    motion::Vector{Int}
    hist::History

    function Game(board)
        new(board, CartesianIndex(1, 1), 0, 0, 0, zeros(Int, 4), History(128))
    end
end

record(g::Game) = record(g.hist,
    Configuration(g.board, g.newtile, g.move, g.depth, g.score))

function Base.show(io::IO, g::Game)
    print(io, "Game $(g.board) $(g.newtile) move $(g.move) depth $(g.depth)")
end

Base.getindex(g::Game, i...) = g.board[i...]
Base.setindex!(g::Game, x, i...) = Base.setindex!(g.board, x, i...)
Base.lastindex(g::Game) = Base.lastindex(g.board)

"""
    plot(g::Game)

Plot game's configuration.
"""
function plot(g::Game)
    c = Configuration(g.board, g.newtile, g.move, g.depth, g.score)
    plot(c)
end

"""
    initgame()

Return an initial game, with only two random tiles.
"""
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
    setcareful(d::Tuple{Int, Int, Int})

Set a tuple of three parameters for computation of the recursive depth:
  * initial depth
  * maximal depth
  * corner size , ie. number of large tiles that triggers depth's incrementation
"""
function setcareful(d::Tuple{Int, Int, Int})
    global careful = d
end

setcareful(initd::Int, maxd::Int, cornersize::Int) =
    setcareful((initd, maxd, cornersize))

setcareful() = setcareful(5, 6, 4)

"""
    computedepth(g::Game)

Compute recursive evaluation's depth, using parameter
`careful` = `(initd, maxd, cornersize)`
  * initially depth = `initd`
  * depth is incremented if the number of
    large tiles (f and above) is greater than `cornersize`
  * depth is never greater than `maxd`
  * no incrementation if the expected score is greater than 128
"""
function computedepth(g::Game)
    initd, maxd, cornersize = careful
    depth = initd
    b = g.board
    c = count(b .> 6)
    if g.score < 128
        c > cornersize && (depth += c - cornersize)
        depth = min(depth, maxd)
    end
    depth
end

"""
    move!(g::Game, depth::Int=0)

Compute the direction `bestdir` of the slide with best evaluation,
using recursive evaluation, up to `depth`.
If this direction is zero, there is no legal move,
otherwise `g.board` and `g.move` are updated.
Return `bestdir`.
"""
function move!(g::Game, depth::Int)
    if g.score >= 128 # ménage sur le plateau et dans la mémoire
        empty!(staticache)
        empty!(meancache)
    end
    b = g.board
    bestestim = sadestim
    bestdir = 0
    # directions, order matters, last dir must be "safe"
    ds = [2, 4, 1, 3]
    n = 0
    local newboard::Board
    while length(ds) > 0
        dir = popfirst!(ds)
        n += 1
        bs, sc, moved = slide(b, dir)
        if moved
            # bs[1] == 0 -> bad move
            if bs[1] == 0 && n <= 4
                push!(ds, dir)  # see later, if necessary
                continue
            end
            # bs[1] == 0 && println("Trying bad move $b n=$n dir=$dir ds=$ds")
            e = meaneval(bs, depth)
            e = Estimation(e.val, e.score + sc)
            if bestestim < e
                bestestim = e
                bestdir = dir
                # newboard = copy(bs)
                newboard = bs
                g.score = e.score
            end
        end
        # needless looking at bad moves
        n == 4 && bestdir > 0 && break
    end
    if bestdir > 0
        # g.board = copy(newboard)
        g.board = newboard
        g.move += 1
        g.motion[bestdir] += 1
    end
    bestdir
end

"""
    play!(g::Game [,display=] [,moves=] [,target=])

Play a game, with current state of `g` as starting point.

  * If keyword argument `display` is `true` (default is `false`),
    `g` is plotted after each move.
  * The number of moves may be bounded by the optional keyword
    argument `moves`, thereafter the game stops
    -- and may be resumed by issuing again `play!(g)`.
  * Optional keyword argument `target` is a couple `(t,p)`
    that stops the game as soon as the tile `t` appears
    in position `p`.

Return `true` if the number of moves or the target are reached,
`false` if the game stops for lack of valid move.
"""
function play!(g::Game;
    display::Bool=false, moves::Int=100_000, target::Tuple{Int,Int}=(16,1))
    global hits_meancache, misses_meancache
    global hits_staticeval, misses_staticeval
    n = g.move
    t, p = target   # target value, position
    while g.move < n + moves
        if t < 16   # otherwise target unreachable
            large = count(g.board .>= t)
            if large >= p
                large = count(g.board .> t)
                large >= p - 1 && return true
            end
        end
        d = computedepth(g)
        if d != g.depth
            if display
                plt.title("Depth $d", loc="center", color="blue")
                # nécessaire pour affichage en temps réel :
                plt.pause(0.01)
            end
            g.depth = d
        end
        move!(g, d) > 0 || return false
        g.newtile = tileinsert!(g.board)
        display && plot(g)
        record(g)
    end
    display && plot(g)
    return true
end

"""
    back!(g::Game, i)

Restore the game `g` to a previous state.
The integer `i` is an index in the circular buffer `g.hist` :

```
    back!(g,-1) # cancel the last move

    back!(g, 1) # restore the game at the beginning of the history
```

Caution: `g.hist` is not updated.
"""
function back!(g::Game, i)
    c = g.hist[i]
    g.board = c.board
    g.newtile = c.newtile
    g.move = c.move
end

"""
    force!(g::Game, dir::Int)

Force a move in the required direction,
and plot the result:

    force!(g,3) # force a move up
"""
function force!(g::Game, dir::Int)
    b, score, moved = slide(g.board, dir)
    moved || error("Illegal direction")
    g.board = b
    g.newtile = tileinsert!(b)
    g.move += 1
    plot(g)
    record(g)
    return
end

"""
    xplay!(g::Game, n::Int [, display = true])

Sequence of plays, alternating quick progressions and
careful ones. The sequence stops as soon as
the tile `14` (i.e. `2^14=16384`) -- resp. `13, 12` --
appears in position `n`.
If `n=4`, the target is the tile `15`.

Optional keyword argument `display` (default `false`),
as in the function `play()`.
"""
function xplay!(g::Game, n::Int; display::Bool=false)
    d = display
    for p in n:4
        setcareful(3, 6, 3)
        println("quick play, careful = $careful")
        play!(g, target = (9, 4), display = d) || return false
        setcareful(5, 6, 4)
        if n < 4
            t = p < 4 ? (14 - p, p) : (15 - n, n)
        else
            t = (15, 1)
        end
        println("target $t, careful = $careful")
        play!(g, target = t, display = d) || return false
    end
    return true
end

"""
    evals(b::Board, depth)

Return a matrix `u`, where `u[i,j]` is the evaluation of move `i`
(i.e. in the direction `i`) up to depth `j-1` --
thus first column gives static evaluations.
"""
function evals(b::Board, depth::Int)
    empty!(staticache)
    empty!(meancache)
    u = Matrix{Estimation}(undef, 4, depth)
    for dir = 1:4
        bs, sc, moved = slide(b, dir)
        for k = 1:depth
            if moved
                e = meaneval(bs, k - 1)
                e = Estimation(e.val, e.score + sc)
            else
                e = sadestim
            end
            u[dir, k] = e
        end
    end
    u
end

"""
    repartition(n [,game =] [,verbose =] [,target =])

Play `n` games and return a tuple of statistics:
  * average number of moves
  * an array `hsup`, where `hsup[i]` is the number of games
    that halted     with 2^i as the largest tile
  * an array of the games played (including their histories).

Optional keyword arguments :
  * `game` specifies the starting game,
    otherwise it's computed by `initgame()`
  * if `verbose` is true (default), each played game is
    displayed when it halts,
    as well as the current average number of moves,
    and `hsup[10:15]`, ie. an array filled with
    the number of games that reached so far 1K, 2K, 4K ... 32K.
  * `target` is a couple `(t,p)`
    that stops the games as soon as the tile `t` appears
    in position `p`.
"""
function repartition(n; game = nothing, verbose = true, target = (16, 1))
    println("gamma = $gamma")
    print("careful = $careful ")
    println("sq, sw = $sq, $sw")
    # println("meaneval nfz, dfz = $nfz, $dfz")
    hsup = zeros(Int, 16)
    nmoves = 0
    hgames = Vector{Game}(undef, n)
    local hmoves
    for i = 1 : n
        g = (game === nothing) ? initgame() : deepcopy(game)
        play!(g, target = target)
        nmoves += g.move
        sup = maximum(g.board)
        hsup[sup] += 1
        hmoves = div(nmoves,i)
        if verbose
            println("$i: $g")
            b = length(g.board)
            if b == 16
                a, b = 10, 15
            else
                a, b = b - 4, b + 1
            end
            println("$hmoves $(hsup[a:b])")
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

"""
    freeze(b::Board, m::Int)

Experimental. Return the vector of cartesian coordinates of cells that may be frozen.
Argument `m` is the minimal value of frozen tiles;
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
function freeze(b::Board, m::Int)
    ifrozen = findall(b .>= m)
    n = length(ifrozen)
    if n > 1
        u = sort(b[ifrozen], rev = true)
        for i in 1 : n - 1
            # @inbounds useless (test btime)
            if u[i] == u[i + 1]
                m = u[i] + 1
                ifrozen = findall(b .>= m)
                break
            end
        end
    end
    # ifree = findall(b .< m)
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

setgamma()
setcareful()
end
