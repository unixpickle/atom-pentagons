{Pentagon, generatePentagons} = require './pentagon_api'

REDRAW_INTERVAL = 1000/24

intervalID = null

editors = []
states = []
canvases = []

module.exports =
  config:
    pentagonColor:
      type: 'string'
      default: 'rgba(255,255,255,0.02)'
      description: 'Allowed color(s) for a polygon. ' +
        'Optionally a list, separated by semicolons (e.g. "#fff;#123").'
    numberOfSides:
      type: 'integer'
      default: 5
      minimum: 3
    numberOfPentagons:
      type: 'integer'
      default: 18
      minimum: 1
  deactivate: ->
    clearInterval intervalID
    intervalID = null
    for c, i in canvases
      if c?
        c.parentElement.removeChild c
        canvases[i] = null
  activate: ->
    intervalID = setInterval redraw, REDRAW_INTERVAL

initializeModule = ->
  atom.workspace.observeTextEditors registerEditor
  atom.config.observe 'pentagons.numberOfPentagons', recreatePentagonStates
  atom.config.observe 'pentagons.pentagonColor', recreatePentagonStates
  window.addEventListener 'resize', ->
    redraw() if intervalID?

registerEditor = (editor) ->
  editor.onDidDestroy ->
    idx = editors.indexOf editor
    if idx > 0
      editors.splice idx, 1
      states.splice idx, 1
      canvases.splice idx, 1
  editors.push editor
  states.push randomPentagonState()
  canvases.push null
  registerBackgroundFixer editor

redraw = ->
  for editor, i in editors
    view = atom.views.getView editor
    unless view.style.display is 'none'
      fixBackgroundColors editor
      unless canvases[i]?
        c = document.createElement 'canvas'
        canvases[i] = c
        c.style.position = 'absolute'
        c.style.width = '100%'
        c.style.height = '100%'
        root = view.shadowRoot
        lines = root.querySelector '.lines'
        lines.insertBefore c, lines.firstChild
      canvas = canvases[i]
      canvas.width = canvas.offsetWidth
      canvas.height = canvas.offsetHeight
      drawPentagons canvas, states[i]
    else
      if canvases[i]?
        canvases[i].parentElement.removeChild canvases[i]
        canvases[i] = null

registerBackgroundFixer = (editor) ->
  fixBackgroundColors editor
  view = atom.views.getView(editor).shadowRoot
  container = view.querySelector '.lines > div'
  observer = new MutationObserver ->
    fixBackgroundColors editor
  config =
    attributes: false
    childList: true
    characterData: false
    subtree: false
  observer.observe container, config

fixBackgroundColors = (editor) ->
  # By default each chunk of lines has a background
  # color which seems unneeded.
  view = atom.views.getView(editor).shadowRoot
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

  sideCount = atom.config.get 'pentagons.numberOfSides'
  Pentagon.allPentagons = state
  for pentagon in state
    frame = pentagon.frame()
    centerX = frame.x*size + xOff
    centerY = frame.y*size + yOff
    radius = size * frame.radius

    # TODO: figure out non-flickery way to use frame.opacity.
    ctx.fillStyle = pentagon.color
    ctx.beginPath()
    for j in [0..sideCount-1]
      x = Math.cos(frame.rotation+j*Math.PI*2/sideCount)*radius + centerX
      y = Math.sin(frame.rotation+j*Math.PI*2/sideCount)*radius + centerY
      if j is 0
        ctx.moveTo x, y
      else
        ctx.lineTo x, y
    ctx.closePath()
    ctx.fill()

recreatePentagonStates = ->
  i = 0
  while i < states.length
    states[i] = randomPentagonState()
    i++

randomPentagonState = ->
  Pentagon.allPentagons = []
  count = atom.config.get 'pentagons.numberOfPentagons'
  generatePentagons(count)
  res = Pentagon.allPentagons
  for pentagon in res
    pentagon.color = randomPentagonColor()
  return res

randomPentagonColor = ->
  colors = atom.config.get('pentagons.pentagonColor').split ';'
  colors = for color in colors
    color.trim()
  return colors[Math.floor(Math.random() * colors.length)]

initializeModule()
