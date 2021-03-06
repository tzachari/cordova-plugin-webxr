const fs = require( 'fs' );
const path = require( 'path' );

module.exports = function( ctx ) {
  var rootDir = path.join( ctx.opts.plugin.dir, 'XRViewer' );
  
  var replaceInDir = dir => {
    fs.readdirSync( dir ).forEach( f => {
      var file = path.join( dir, f );
      if ( fs.statSync( file ).isFile() ) {
        if ( path.extname( f ) != '.js' ) {
          var data = fs.readFileSync( file, 'utf8' );
          data = data.replace( /^.*(XCGLogger).*$/mg, '' );
          data = data.replace( /func appDelegate[^}]*\n}/, '' );
          data = data.replace( /= .fade/, '= kCATransitionFade' );
          fs.writeFileSync( file, data, 'utf8' );
        } 
      } else {
        replaceInDir( file );          
      }
    } )
  }

  if ( rootDir ) {
    replaceInDir( rootDir );
  }
}
