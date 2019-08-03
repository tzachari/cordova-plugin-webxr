const fs = require( 'fs' );
const path = require( 'path' );

module.exports = function( ctx ) {
  var rootdir = ctx.opts.plugin.dir;

  var replaceInDir = dir => {
    fs.readdirSync( dir ).forEach( f => {
      var file = path.join( dir, f );
      if ( fs.statSync( file ).isFile() ) {
        if ( path.extname( f ) != '.js' ) {
          var data = fs.readFileSync( file, 'utf8' );
          data = data.replace( /^.*(CocoaLumberjack|DDLogLevel).*$/mg, '' );
          fs.writeFileSync( file, data, 'utf8' );
        }
      } else {
        replaceInDir( file );          
      }
    } )
  }

  if ( rootdir ) {
    replaceInDir( rootdir );
  }
}
