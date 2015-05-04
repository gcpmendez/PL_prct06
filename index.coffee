# Importamos express
express = require('express')

# Ruteamos usando el objeto express.router()
router = express.Router()


### GET home page. ###

# Ruteamos   ---   Parseamos la ruta / y devolvemos el index.
#router.get '/', (req, res, next) ->    
#  res.render 'index', title: 'Express'
#  return
#module.exports = router


module.exports = (grunt) ->
  grunt.initConfig
    coffee:
      dev:
        expand: true
        cwd: 'assets/js/'
        dest: '<%= coffee.dev.cwd %>'
        ext: '.js'
        src: [
          '*.coffee'
          '**/*.coffee'
        ]
        options:
          bare: true
          sourceMap: true

module.exports =
  index: (req, res) ->
    res.render 'index', { title: 'Predictive Recursive Descent Parser' }
    
    
    
    