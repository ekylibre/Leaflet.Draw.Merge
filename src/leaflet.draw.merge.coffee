L = require 'leaflet'
_ = require 'lodash'

turf = require '@turf/helpers'
turfMeta = require '@turf/meta'
turfBooleanOverlap = require '@turf/boolean-overlap'
turfUnion = require '@turf/union'
booleanPointOnLine = require '@turf/boolean-point-on-line'
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

    @_featureGroup.on 'layeradd', @refreshAvailableLayers, @
    @_featureGroup.on 'layerremove', @refreshAvailableLayers, @

    # poly = new L.Polygon [[45.824114, -0.796735],[45.824368, -0.795362],[45.82453, -0.794588],[45.826915, -0.795758],[45.826863, -0.796927],[45.825629, -0.79771],[45.824114, -0.796735]]
    # @_featureGroup.addData poly.toGeoJSON()
    poly = new L.Polygon [[[45.824114, -0.796735],[45.824244,-0.796029],[45.824409,-0.795145],[45.824509,-0.794611],[45.824811,-0.795321],[45.824579, -0.79664],[45.824114, -0.796735]]]
    @_featureGroup.addData poly.toGeoJSON()

    poly2 = new L.Polygon [[[45.824483, -0.794565],[45.824308, -0.794476],[45.82399, -0.794315],[45.82394, -0.79429],[45.823719,-0.794154],[45.82434,-0.793379],[45.824728,-0.793706],[45.824483,-0.794565]]]
    @_featureGroup.addData poly2.toGeoJSON()



    @_map.on L.Merging.Event.SELECT, @_mergeMode, @

    @_map.on 'zoomend moveend', () =>
      @refreshAvailableLayers()

    # @_map.on 'mousemove', @_selectLayer, @
    # @_map.on 'mousemove', @_mergeMode, @

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

    layer.bindPopup("stamp" + L.stamp(layer))
    layer.on 'click', @_activate, @
    #
    # poly1 = turf.polygon([[[0,0],[0,5],[5,5],[5,0],[0,0]]])
    # poly2 = turf.polygon([[[1,1],[1,6],[6,6],[6,1],[1,1]]])
    #
    # poly1Leaf = new L.Polygon []
    # poly1Leaf.fromTurfFeature(poly1)
    # poly1Leaf.addTo @_map
    #
    # poly2Leaf = new L.Polygon []
    # poly2Leaf.fromTurfFeature(poly2)
    # poly2Leaf.addTo @_map
    #
    # console.error turfBooleanOverlap(poly1, poly2)
    #
    # union = turfUnion.default(poly1, poly2)
    # poly3 = new L.Polygon [], color: 'red'
    # console.error union
    # poly3.fromTurfFeature(union)
    # poly3.addTo @_map


  _unselectLayer: (e) ->
    layer = e.layer or e.target or e
    layer.selected = false
    if @options.selectedPathOptions
      layer.setStyle layer.options.disabled

    # if layer.merging
      # layer.merging.disable()
      # delete layer.merging

    # @_map.on 'mousemove', @_selectLayer, @

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

  _activate: (e) ->
    layer = e.target || e.layer || e

    if !layer.selected
      layer.selected = true
      layer.setStyle layer.options.selected

      if @_activeLayer
        @_unselectLayer @_activeLayer

      @_activeLayer = layer

      @_map.fire L.Merging.Event.SELECT, layer: @_activeLayer
    else
      layer.selected = false
      layer.setStyle(layer.options.disabled)

      @_activeLayer = null
      @_map.fire L.Merging.Event.UNSELECT, layer: layer

  _mergeMode: ->

    i = 0
    k = 0

    # for p in @_activeLayer.getLatLngs()[0][0]
      # console.error p
      # L.marker(p).addTo @_map

    #find contiguous polygons
    @_availableLayers.eachLayer (layer) =>
      if L.stamp(layer) != L.stamp(@_activeLayer) && k == 0

        console.error "try:", L.stamp(layer)
        activePoly = @_activeLayer.toTurfFeature()
        turfLayer = layer.toTurfFeature()

        console.error activePoly, turfLayer

        overlap = turfBooleanOverlap(activePoly, turfLayer)

        console.error overlap

        if overlap
          console.error turfLayer.geometry.coordinates

          outerRing = @_activeLayer.outerRingAsTurfLineString()

          j = 0

          turfCoords = []

          for coord in turfLayer.geometry.coordinates[0]
            closest = undefined
            coord2 = undefined

            if j == 1 || j == 2
              closest = L.GeometryUtil.closest(@_map, @_activeLayer, L.latLng(coord[1], coord[0]))
              console.error "closest:", closest

            if closest
              coord2 = [closest.lng, closest.lat]
              console.error 'prev: ', coord, 'next:',coord2
              console.error 'retest', L.GeometryUtil.closest(@_map, @_activeLayer, L.latLng(coord2[1], coord2[0]))

            if coord2
              point = turf.point(coord2)
              pt = L.latLng(coord2[1], coord2[0])
              turfCoords.push coord2

            else
              point = turf.point(coord)
              pt = L.latLng(coord[1], coord[0])
              turfCoords.push coord

            console.error point
            L.marker(pt).addTo @_map
            console.error 'on the line:',booleanPointOnLine.default(point, outerRing)
            j++

          turfPoly = turf.polygon([turfCoords])
          console.error turfPoly
          union = turfUnion.default(activePoly, turfPoly)
          poly3 = new L.Polygon [], color: 'red'
          console.error union
          poly3.fromTurfFeature(union)
          poly3.addTo @_map

          k = 1

        i++

  _merge: (->)

  _hasAvailableLayers: ->
    @_availableLayers.getLayers().length != 0

L.Merge.include L.Mixin.Events
