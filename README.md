# Leaflet.Draw.Merge

This plugin extends Leaflet.Draw to provide merge capabilities.
It takes advantage of RTree spatial index if available.

Works with Leaflet 1.2.0 and Leaflet.Draw 0.4.12

## Usage

```
options:
  position: 'topleft'
  featureGroup: undefined
  disabledPathOptions:
    dashArray: null
    fill: true
    fillColor: '#fe57a1'
    fillOpacity: 0.1
    maintainColor: true
  selectedPathOptions:
    dashArray: null
    fill: true
    fillColor: '#fe57a1'
    fillOpacity: 0.9
    maintainColor: true
  mergingPathOptions:
    dashArray: '10, 10'
    fill: false
    color: '#fe57a1'

new L.Merge map, options
```

## Installation
  Via NPM: ```npm install leaflet-draw-merge```

  Include ```dist/leaflet.draw.merge.js``` on your page.

  Or, if using via CommonJS (Browerify, Webpack, etc.):
  ```
var L = require('leaflet')
require('leaflet-draw-merge')
```
## Development  
This plugin is powered by webpack:

* Use ```npm run watch``` to automatically rebuild while developing.
* Use ```npm test``` to run unit tests.
* Use ```npm run build``` to minify for production use, in the ```dist/```
