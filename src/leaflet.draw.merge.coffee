L = require 'leaflet'
_ = require 'lodash'

turf = require '@turf/helpers'
turfMeta = require '@turf/meta'
require 'leaflet-geometryutil'

L.Merging = {}
L.Merging = {}
L.Merging.Event = {}
L.Merging.Event.START = "merge:start"
L.Merging.Event.STOP = "merge:stop"
L.Merging.Event.SELECT = "merge:select"
L.Merging.Event.UNSELECT = "merge:unselect"
L.Merging.Event.MERGED = "merge:merged"

class L.Merge extends L.Handler
  @TYPE: 'merge'

  constructor: (map, options) ->
    @type = @constructor.TYPE
    @_map = map
    super map
    @options = _.merge @options, options

    @_featureGroup = options.featureGroup
    @_availableLayers = new L.FeatureGroup
    @_activeLayer = undefined
    @_uneditedLayerProps = []

    if !(@_featureGroup instanceof L.FeatureGroup)
      throw new Error('options.featureGroup must be a L.FeatureGroup')

  enable: ->
    if @_enabled or !@_featureGroup.getLayers().length
      return

    @fire 'enabled', handler: @type

    @_map.fire L.Merging.Event.START, handler: @type

    super

    @_availableLayers.on 'layeradd', @_enableLayer, @
    @_availableLayers.on 'layerremove', @_disableLayer, @

    @_map.on L.Merging.Event.SELECT, @_mergeMode, @

    @_map.on 'zoomend moveend', () =>
      @refreshAvailableLayers()

    # @_map.on 'mousemove', @_selectLayer, @
    @_map.on 'mousemove', @_mergeMode, @

  disable: ->
    if !@_enabled
      return
    @_availableLayers.off 'layeradd', @_enableLayer, @
    @_availableLayers.off 'layerremove', @_disableLayer, @

    super

    @_map.fire L.Merging.Event.STOP, handler: @type

    @_map.off L.Merging.Event.SELECT, @_startCutDrawing, @


    @fire 'disabled', handler: @type
    return

  addHooks: ->

    @refreshAvailableLayers()

    @_availableLayers.eachLayer @_enableLayer, @

  refreshAvailableLayers: ->
    return unless @_featureGroup.getLayers().length

    #RTree
    if typeof @_featureGroup.search == 'function'
      newLayers = new L.LayerGroup(@_featureGroup.search(@_map.getBounds()))

      removeList = @_availableLayers.getLayers().filter (layer) ->
        !newLayers.hasLayer layer

      if removeList.length
        for l in removeList
          @_availableLayers.removeLayer l

      addList = newLayers.getLayers().filter (layer) =>
        !@_availableLayers.hasLayer layer

      if addList.length
        for l in addList
          @_availableLayers.addLayer(l)

    else
      @_availableLayers = @_featureGroup

  removeHooks: ->
    @_featureGroup.eachLayer @_disableLayer, @

  save: ->
    # selectedLayers = new L.LayerGroup
    # @_featureGroup.eachLayer (layer) ->
    #   if layer.selected
    #     selectedLayers.addLayer layer
    #     layer.selected = false
    # @_map.fire L.Merging.Event.SELECTED, layers: selectedLayers

    #TMP
    @_featureGroup.eachLayer (l) =>
      @_map.removeLayer(l)
    @_featureGroup.addLayer(@_activeLayer._poly)
    @_featureGroup.addTo(@_map)
    # @_map.removeLayer(@_activeLayer._poly)
    delete @_activeLayer._poly
    delete @_activeLayer
    return

  _enableLayer: (e) ->
    layer = e.layer or e.target or e

    layer.options.original = L.extend({}, layer.options)

    if @options.disabledPathOptions
      pathOptions = L.Util.extend {}, @options.disabledPathOptions

      # Use the existing color of the layer
      if pathOptions.maintainColor
        pathOptions.color = layer.options.color
        pathOptions.fillColor = layer.options.fillColor

      layer.options.disabled = pathOptions

    if @options.selectedPathOptions
      pathOptions = L.Util.extend {}, @options.selectedPathOptions

      # Use the existing color of the layer
      if pathOptions.maintainColor
        pathOptions.color = layer.options.color
        pathOptions.fillColor = layer.options.fillColor

      layer.options.selected = pathOptions

    layer.setStyle layer.options.disabled

  _selectLayer: (e) ->
    # layer = e.target || e.layer || e
    mouseLatLng = e.latlng
    for layer in @_availableLayers.getLayers()
      mousePoint = mouseLatLng.toTurfFeature()
      polygon = layer.toTurfFeature()

      if turfinside.default(mousePoint, polygon)
        if layer != @_activeLayer
          @_activate layer, mouseLatLng
        return

    if @_activeLayer && !@_activeLayer.glue
      @_unselectLayer @_activeLayer

  _unselectLayer: (e) ->
    layer = e.layer or e.target or e
    layer.selected = false
    if @options.selectedPathOptions
      layer.setStyle layer.options.disabled

    if layer.merging
      layer.merging.disable()
      delete layer.merging

    @_map.on 'mousemove', @_selectLayer, @

    @_activeLayer = null

  _disableLayer: (e) ->
    layer = e.layer or e.target or e
    layer.selected = false
    # Reset layer styles to that of before select
    if @options.selectedPathOptions
      layer.setStyle layer.options.original

    delete layer.options.disabled
    delete layer.options.selected
    delete layer.options.original

  _activate: (e, latlng) ->
    layer = e.target || e.layer || e

    if !layer.selected
      layer.selected = true
      layer.setStyle layer.options.selected

      if @_activeLayer
        @_unselectLayer @_activeLayer

      @_activeLayer = layer

      @_map.fire L.Merging.Event.SELECT, layer: @_activeLayer, latlng: latlng
    else
      layer.selected = false
      layer.setStyle(layer.options.disabled)

      @_activeLayer.merging.disable()
      delete @_activeLayer.merging

      @_activeLayer = null
      @_map.fire L.Merging.Event.UNSELECT, layer: layer

  _merge: (->)

  _hasAvailableLayers: ->
    @_availableLayers.length != 0

L.Merge.include L.Mixin.Events
