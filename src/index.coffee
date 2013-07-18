'use strict'

fs     = require 'fs'
path   = require 'path'

_      = require 'lodash'
logger = require 'logmimosa'

config = require './config'
utils  = require './utils'

mimosaRequire = null
basePath = null
dataFile = 'data.js'

assets = [
  "d3.v3.min.js"
  "dependency_graph.js"
  "main.js"
  "main.css"
  "index.html"
]

registration = (mimosaConfig, register) ->
  mimosaRequire = mimosaConfig.installedModules['mimosa-require']
  if not mimosaRequire
    return logger.error "mimosa-dependency-graph is configured but cannot be used unless mimosa-require is installed and used."
  
  basePath = mimosaConfig.watch.compiledJavascriptDir
  ext = mimosaConfig.extensions

  register ['postBuild'], 'beforeOptimize',  _writeStaticAssets
  register ['postBuild'], 'beforeOptimize',  _generateGraphData

  register ['add','update', 'remove'], 'afterWrite', _generateGraphData, ext.javascript

  # TODO clean?

# Generate an object containing nodes and links data that can be used
# to construct a d3.js force-directed graph.
#
# In this case, `nodes` is just an array of module names, while `links`
# is an array of objects that specify the dependency between a module
# (source) and another (target).
_generateGraphData = (mimosaConfig, options, next) ->
  dependencyInfo = mimosaRequire.dependencyInfo()
  nodes = []
  links = []

  for module, dependencies of dependencyInfo
    nodes.push module, dependencies...
    links.push { source: module, target: dep } for dep in dependencies

  data =
    nodes: for node in (nodes = _.uniq(nodes))
      filename: utils.formatFilename node, basePath
    links: for link in links
      source: nodes.indexOf link.source
      target: nodes.indexOf link.target

  # Output the dependency graph data to a file in the assets folder
  filename = path.join config.assetFolderFull, dataFile
  fs.writeFileSync filename, "window.MIMOSA_DEPENDENCY_DATA = #{JSON.stringify(data, null, 2)}"
  logger.info "Created file [[ #{filename} ]]"

  next()

# Write all necessary html, js, css files to the assets folder
_writeStaticAssets = (mimosaConfig, options, next) ->
  config = mimosaConfig.dependencyGraph

  utils.mkdirIfNotExists config.assetFolderFull

  assets.filter (asset) ->
    config.safeAssets.indexOf asset is -1
  .forEach (asset) ->
    inFile = path.join __dirname, '..', 'assets', asset
    outFile = path.join config.assetFolderFull, asset
    utils.copyFile inFile, outFile

  next()

module.exports =
  registration: registration
  defaults:     config.defaults
  placeholder:  config.placeholder
  validate:     config.validate
