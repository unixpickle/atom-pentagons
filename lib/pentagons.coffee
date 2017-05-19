{Pentagon, generatePentagons} = require './pentagon_api'
{CompositeDisposable} = require 'atom'

REDRAW_INTERVAL = 1000/24

class Pentagons
  constructor: ->
    @disposable = new CompositeDisposable
    @mutationObservers = []
    @editors = []
    @states = []
    @canvases = []
    @intervalID = setInterval (=> @redraw()), REDRAW_INTERVAL
    @resizeHandler = (=> @redraw())
    window.addEventListener 'resize', @resizeHandler
    @registerObservers()

  dispose: ->
    @disposable.dispose()
    for mo in @mutationObservers
      mo.disconnect()
    clearInterval @intervalID
    for c in @canvases
      if c?
        c.parentElement.removeChild c
    window.removeEventListener 'resize', @resizeHandler

  redraw: ->
    for editor, i in @editors
      view = atom.views.getView editor
      unless view.style.display is 'none'
        fixBackgroundColors editor
        unless @canvases[i]?
          c = document.createElement 'canvas'
          @canvases[i] = c
          c.style.position = 'absolute'
          c.style.width = '100%'
          c.style.height = '100%'
          lines = view.querySelector '.lines'
          lines.insertBefore c, lines.firstChild
        canvas = @canvases[i]
        canvas.width = canvas.offsetWidth
        canvas.height = canvas.offsetHeight
        drawPentagons canvas, @states[i]
      else
        if @canvases[i]?
          @canvases[i].parentElement.removeChild @canvases[i]
          @canvases[i] = null

  registerObservers: ->
    o = atom.workspace.observeTextEditors (e) => @registerEditor e
    @disposable.add o

    prefs = ['pentagonColor', 'numberOfPentagons', 'showTriangles',
      'showSquares', 'showPentagons', 'showHexagons',
      'showHeptagons', 'showOctogons', 'showCircles']
    for pref in prefs
      o = atom.config.observe 'pentagons.'+pref, =>
        @recreatePentagonStates()
      @disposable.add o

  registerEditor: (editor) ->
    @disposable.add editor.onDidDestroy =>
      idx = @editors.indexOf editor
      if idx > 0
        @editors.splice idx, 1
        @states.splice idx, 1
        @canvases.splice idx, 1
    @editors.push editor
    @states.push randomPentagonState()
    @canvases.push null
    @registerBackgroundFixer editor

  registerBackgroundFixer: (editor) ->
    fixBackgroundColors editor
    view = atom.views.getView(editor)
    container = view.querySelector '.lines > div'
    observer = new MutationObserver ->
      fixBackgroundColors editor
    config =
      attributes: false
      childList: true
      characterData: false
      subtree: false
    observer.observe container, config
    @mutationObservers.push observer

  recreatePentagonStates: ->
    i = 0
    while i < @states.length
      @states[i] = randomPentagonState()
      i++

pentagonInstance = null

module.exports =
  config:
    pentagonColor:
      type: 'string'
      default: 'rgba(255,255,255,0.02)'
      description: 'Allowed color(s) for a polygon. ' +
        'Optionally a list, separated by semicolons (e.g. "#fff;#123").'
      order: 1
    numberOfPentagons:
      type: 'integer'
      default: 18
      minimum: 1
      order: 2
    showTriangles:
      type: 'boolean'
      default: false
      order: 3
    showSquares:
      type: 'boolean'
      default: false
      order: 4
    showPentagons:
      type: 'boolean'
      default: true
      order: 5
    showHexagons:
      type: 'boolean'
      default: false
      order: 6
    showHeptagons:
      type: 'boolean'
      default: false
      order: 7
    showOctogons:
      type: 'boolean'
      default: false
      order: 8
    showCircles:
      type: 'boolean'
      default: false
      order: 9
  deactivate: ->
    pentagonInstance.dispose()
    pentagonInstance = null
  activate: ->
    pentagonInstance = new Pentagons

fixBackgroundColors = (editor) ->
  # By default each chunk of lines has a background
  # color which seems unneeded.
  view = atom.views.getView(editor)
  divs = view.querySelectorAll '.lines > div > div'
  for d in divs
    d.style.backgroundColor = ''

drawPentagons = (canvas, state) ->
  width = canvas.width
  height = canvas.height
  ctx = canvas.getContext '2d'
  ctx.clearRect 0, 0, width, height

  size = Math.max width, height
  xOff = 0
  yOff = 0
  if width < height
    xOff = -(height - width) / 2
  else
    yOff = -(width - height) / 2

  Pentagon.allPentagons = state
  for pentagon in state
    frame = pentagon.frame()
    centerX = frame.x*size + xOff
    centerY = frame.y*size + yOff
    radius = size * frame.radius

    # TODO: figure out non-flickery way to use frame.opacity.
    ctx.fillStyle = pentagon.color
    ctx.beginPath()
    unless pentagon.sideCount is Infinity
      count = pentagon.sideCount
      for j in [0..count-1]
        x = Math.cos(frame.rotation+j*Math.PI*2/count)*radius + centerX
        y = Math.sin(frame.rotation+j*Math.PI*2/count)*radius + centerY
        if j is 0
          ctx.moveTo x, y
        else
          ctx.lineTo x, y
      ctx.closePath()
    else
      ctx.arc centerX, centerY, radius, 0, Math.PI*2, false
    ctx.fill()

randomPentagonState = ->
  Pentagon.allPentagons = []
  count = atom.config.get 'pentagons.numberOfPentagons'
  generatePentagons(count)
  res = Pentagon.allPentagons
  for pentagon in res
    pentagon.color = randomPentagonColor()
    pentagon.sideCount = randomPentagonSideCount()
  return res

randomPentagonColor = ->
  colors = atom.config.get('pentagons.pentagonColor').split ';'
  colors = for color in colors
    color.trim()
  return colors[Math.floor(Math.random() * colors.length)]

randomPentagonSideCount = ->
  attributes = ['showTriangles', 'showSquares', 'showPentagons',
    'showHexagons', 'showHeptagons', 'showOctogons', 'showCircles']
  sideCounts = [3, 4, 5, 6, 7, 8, Infinity]
  useCounts = []
  for attr, i in attributes
    if atom.config.get('pentagons.'+attr)
      useCounts.push sideCounts[i]
  if useCounts.length is 0
    return 5
  return useCounts[Math.floor(Math.random() * useCounts.length)]
