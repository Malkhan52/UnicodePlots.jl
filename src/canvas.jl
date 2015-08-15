
import Base.show

signs = ['⡀' '⠄' '⠂' '⠁';
         '⢀' '⠠' '⠐' '⠈']

type Canvas
  grid::Array{Char,2}
  pixelWidth::Int
  pixelHeight::Int
  plotOriginX::Float64
  plotOriginY::Float64
  plotWidth::Float64
  plotHeight::Float64
end

function show(io::IO, c::Canvas)
  for y in reverse(1:size(c.grid,2))
    for x in 1:size(c.grid,1)
      print(c.grid[x,y])
    end
    println()
  end
  println("pixelWidth: $(c.pixelWidth)")
  println("pixelHeight: $(c.pixelHeight)")
  println("plotOriginX: $(c.plotOriginX)")
  println("plotOriginY: $(c.plotOriginY)")
  println("plotWidth: $(c.plotWidth)")
  println("plotHeight: $(c.plotHeight)")
end

function Canvas(charWidth::Int, charHeight::Int,
                plotOriginX::Float64, plotOriginY::Float64,
                plotWidth::Float64, plotHeight::Float64)
  charWidth = charWidth < 5 ? 5 : charWidth
  charHeight = charHeight < 5 ? 5 : charHeight
  plotWidth > 0 || throw(ArgumentError("Width has to be positive"))
  plotHeight > 0 || throw(ArgumentError("Width has to be positive"))
  grid = if VERSION < v"0.4-"
    fill(char(0x2800), charWidth, charHeight)
  else
    fill(Char(0x2800), charWidth, charHeight)
  end
  Canvas(grid, charWidth * 2, charHeight * 4, plotOriginX, plotOriginY, plotWidth, plotHeight)
end

function safeRound(num)
  if VERSION < v"0.4-"
    iround(num)
  else
    round(Integer,num)
  end
end

function safeFloor(num)
  if VERSION < v"0.4-"
    ifloor(num)
  else
    floor(Integer,num)
  end
end

function setPixel!(c::Canvas, pixelX::Int, pixelY::Int)
  @assert 0 <= pixelX <= c.pixelWidth
  @assert 0 <= pixelY <= c.pixelHeight
  pixelX = pixelX < c.pixelWidth ? pixelX: pixelX - 1
  pixelY = pixelY < c.pixelHeight ? pixelY: pixelY - 1
  cw, ch = size(c.grid)
  tmp = pixelX / c.pixelWidth * cw
  charX = safeFloor(tmp) + 1
  charXOff = (pixelX % 2) + 1
  if charX < safeRound(tmp) + 1 && charXOff == 1
    charX = charX +1
  end
  charY = safeFloor(pixelY / c.pixelHeight * ch) + 1
  charYOff = (pixelY % 4) + 1
  if VERSION < v"0.4-"
    c.grid[charX,charY] = c.grid[charX,charY] | signs[charXOff, charYOff]
  else
    c.grid[charX,charY] = Char(Uint64(c.grid[charX,charY]) | Uint64(signs[charXOff, charYOff]))
  end
end

function setPoint!(c::Canvas, plotX::Float64, plotY::Float64)
  @assert c.plotOriginX <= plotX < c.plotOriginX + c.plotWidth
  @assert c.plotOriginY <= plotY < c.plotOriginY + c.plotHeight
  plotXOffset = plotX - c.plotOriginX
  pixelX = plotXOffset / c.plotWidth * c.pixelWidth
  plotYOffset = plotY - c.plotOriginY
  pixelY = plotYOffset / c.plotHeight * c.pixelHeight
  setPixel!(c, safeFloor(pixelX), safeFloor(pixelY))
end

function scatterplot{F<:FloatingPoint}(io::IO, X::Vector{F},Y::Vector{F};
                                       width=40, height=10, margin=3,
                                       title::String="", border=:solid, labels=true)
  length(X) == length(Y) || throw(DimensionMismatch("X and Y must be the same length"))
  width = width >= 5 ? width: 5
  height = height >= 5 ? height: 5
  b=borderMap[border]
  minX = min(X...); minY = min(Y...)
  maxX = max(X...); maxY = max(Y...)
  diffX = maxX - minX; diffY = maxY - minY
  smallDiff = min(diffX, diffY)
  padX = 0.01 * diffX; padY = 0.01 * diffY
  plotOriginX = minX - padX; plotWidth = maxX - plotOriginX + padX
  plotOriginY = minY - padY; plotHeight = maxY - plotOriginY + padY
  c = Canvas(width, height, plotOriginX, plotOriginY, plotWidth, plotHeight)
  if minY < 0 < maxY
    for i in linspace(minX, maxX, width*2)
      setPoint!(c, i, 0.)
    end
  end
  for i in 1:length(X)
    setPoint!(c, X[i], Y[i])
  end

  minYString=string(minY)
  maxYString=string(maxY)
  maxLen = labels ? max(length(minYString), length(maxYString)) : 0
  plotOffset = maxLen + margin
  borderPadding = repeat(" ", plotOffset + 1)
  drawTitle(io, borderPadding, title)

  len = length(maxYString)
  padY1 = labels ? string(repeat(" ", margin), repeat(" ", maxLen - len)): ""
  len = length(minYString)
  padY2 = labels ? string(repeat(" ", margin), repeat(" ", maxLen - len)): ""
  borderWidth = width + 1
  drawBorderTop(io, borderPadding, borderWidth, border)
  for y in reverse(1:size(c.grid,2))
    if labels && y == height
      print(padY1, maxYString, " ", b[:l])
    elseif labels && y == 1
      print(padY2, minYString, " ", b[:l])
    else
      print(io, borderPadding, b[:l])
    end
    for x in 1:size(c.grid,1)
      print(io, c.grid[x,y])
    end
    print(io," ", b[:r], "\n")
  end
  drawBorderBottom(io, borderPadding, borderWidth, border)
  if labels
    minXString=string(minX); minLen = length(minXString)
    maxXString=string(maxX); maxLen = length(maxXString)
    print(io, borderPadding, minXString)
    cnt = borderWidth - maxLen - minLen + 1
    pad = cnt > 0 ? repeat(" ", cnt) : ""
    print(io, pad, maxXString, "\n")
  end
end

function lineplot{F<:FloatingPoint}(io::IO, X::Vector{F},Y::Vector{F};
                                    width=40, height=10, margin=3,
                                    title::String="", border=:solid, labels=true)
  length(X) == length(Y) || throw(DimensionMismatch("X and Y must be the same length"))
  minX = min(X...); minY = min(Y...)
  maxX = max(X...); maxY = max(Y...)
  diffX = maxX - minX; diffY = maxY - minY
  smallDiff = min(diffX, diffY)
  xVec = X[1]; yVec = Y[1]
  for i in 2:(length(X))
    tV = collect(X[i-1]:.002smallDiff:X[i])
    tl = length(tV)
    xVec = [xVec; tV]
    yVec = tl > 1 ? [yVec; linspace(Y[i-1],Y[i],tl)]: [yVec; Y[i]]
  end
  scatterplot(io, xVec, yVec; width=width, height=height, margin=margin,
              title=title, border=border, labels=labels)
end

function scatterplot(io::IO, X::Vector{Int},Y::Vector{Int}; args...)
  scatterplot(io,
              convert(Vector{Float64},X),
              convert(Vector{Float64},Y); args...)
end

function scatterplot(X::Vector{Int},Y::Vector{Int}; args...)
  scatterplot(STDOUT, X, Y; args...)
end

function scatterplot{F<:FloatingPoint}(X::Vector{F},Y::Vector{F}; args...)
  scatterplot(STDOUT, X, Y; args...)
end

function lineplot(io::IO, X::Vector{Int},Y::Vector{Int}; args...)
  lineplot(io, X, Y; args...)
end

function lineplot(X::Vector{Int},Y::Vector{Int}; args...)
  lineplot(STDOUT,
           convert(Vector{Float64},X),
           convert(Vector{Float64},Y); args...)
end

function lineplot{F<:FloatingPoint}(X::Vector{F},Y::Vector{F}; args...)
  lineplot(STDOUT, X, Y; args...)
end

function lineplot(io::IO, Y::Function, X::Range; args...)
  y = [Y(i) for i in X]
  lineplot(io,
           convert(Vector{Float64},collect(X)),
           convert(Vector{Float64},y); args...)
end

function lineplot(Y::Function, X::Range; args...)
  lineplot(STDOUT, Y, X; args...)
end
