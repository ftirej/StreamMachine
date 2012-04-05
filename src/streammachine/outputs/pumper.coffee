_u = require 'underscore'

module.exports = class Pumper
    constructor: (stream,req,res) ->
        @req = req
        @res = res
        @stream = stream                
        
        # figure out what we're pulling
        playHead = @stream.rewind.checkOffset req.query.from || req.query.pump
        console.log "requested offset of #{ req.query.from || req.query.pump }. providing #{playHead}."
        
        # grab our pump buffer
        pumpBuf = @stream.rewind.pumpFrom playHead, req.query.pump
                
        secs = playHead / @stream.rewind.framesPerSec
        @stream.log.debug output:"pump", seconds:secs, bytes:pumpBuf.length, "Pumping"
        
        headers = 
            "Content-Type":         "audio/mpeg"
            "Connection":           "close"
            "Transfer-Encoding":    "identity"
            "Content-Length":       pumpBuf.length
        
        # write out our headers
        res.writeHead 200, headers
        
        # send our pump buffer to the client
        @res.end pumpBuf