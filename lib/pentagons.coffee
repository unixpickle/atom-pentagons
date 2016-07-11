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
      default: 'rgba(255, 255, 255, 0.1)'
  deactivate: ->
    clearInterval intervalID
    for c, i in canvases
      if c?
        c.parentElement.removeChild c
        canvases[i] = null
  activate: ->
    intervalID = setInterval redraw, REDRAW_INTERVAL

initializeModule = ->
  atom.workspace.observeTextEditors registerEditor

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

  ctx.fillStyle = atom.config.get 'pentagons.pentagonColor'
  Pentagon.allPentagons = state
  for pentagon in state
    frame = pentagon.frame()
    centerX = frame.x*size + xOff
    centerY = frame.y*size + yOff
    radius = size * frame.radius

    # TODO: figure out non-flickery way to use frame.opacity.
    ctx.beginPath()
    for j in [0..4]
      x = Math.cos(frame.rotation+j*Math.PI*2/5)*radius + centerX
      y = Math.sin(frame.rotation+j*Math.PI*2/5)*radius + centerY
      if j is 0
        ctx.moveTo x, y
      else
        ctx.lineTo x, y
    ctx.closePath()
    ctx.fill()

randomPentagonState = ->
  Pentagon.allPentagons = []
  generatePentagons()
  res = Pentagon.allPentagons
  return res

initializeModule()
